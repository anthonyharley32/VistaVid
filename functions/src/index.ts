/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import { onObjectFinalized, StorageEvent } from "firebase-functions/v2/storage";
import * as logger from "firebase-functions/logger";
import * as admin from 'firebase-admin';
import * as path from 'path';
import * as os from 'os';
import * as fs from 'fs';
import ffmpeg from 'fluent-ffmpeg';
import * as ffmpegInstaller from '@ffmpeg-installer/ffmpeg';
import { Storage } from '@google-cloud/storage';

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Cloud Storage
const storage = new Storage();

// Set ffmpeg path
ffmpeg.setFfmpegPath(ffmpegInstaller.path);

// Constants
const BUCKET_NAME = 'vistavid-be.firebasestorage.app';
const HLS_SEGMENT_DURATION = 6; // Duration of each segment in seconds

// Video quality presets
const QUALITY_PRESETS = [
    { name: '1080p', height: 1080, bitrate: '5000k' },
    { name: '720p', height: 720, bitrate: '2800k' },
    { name: '480p', height: 480, bitrate: '1400k' },
    { name: '360p', height: 360, bitrate: '800k' }
];

interface StorageObject {
    name?: string;
    contentType?: string;
}

interface FFmpegProgress {
    frames: number;
    currentFps: number;
    currentKbps: number;
    targetSize: number;
    timemark: string;
    percent?: number;
}

async function generateVariantPlaylist(outputPath: string, variants: string[]): Promise<void> {
    const masterPlaylist = '#EXTM3U\n' + 
        variants.map((variant, index) => {
            const preset = QUALITY_PRESETS[index];
            return `#EXT-X-STREAM-INF:BANDWIDTH=${parseInt(preset.bitrate) * 1000},RESOLUTION=${preset.height}p\n${variant}`;
        }).join('\n');
    
    await fs.promises.writeFile(path.join(outputPath, 'master.m3u8'), masterPlaylist);
}

async function transcodeToHLS(inputPath: string, outputPath: string, preset: typeof QUALITY_PRESETS[0]): Promise<string> {
    const variantPath = path.join(outputPath, `${preset.name}`);
    await fs.promises.mkdir(variantPath, { recursive: true });
    
    const playlistName = `playlist_${preset.name}.m3u8`;
    const outputPlaylist = path.join(variantPath, playlistName);
    
    await new Promise<void>((resolve, reject) => {
        ffmpeg(inputPath)
            .outputOptions([
                '-profile:v baseline',
                '-level 3.0',
                '-start_number 0',
                `-vf scale=-2:${preset.height}`,
                `-b:v ${preset.bitrate}`,
                `-maxrate ${preset.bitrate}`,
                `-bufsize ${parseInt(preset.bitrate) * 2}k`,
                `-hls_time ${HLS_SEGMENT_DURATION}`,
                '-hls_list_size 0',
                '-hls_segment_filename',
                path.join(variantPath, `segment_%03d.ts`),
                '-f hls'
            ])
            .output(outputPlaylist)
            .on('progress', (progress: FFmpegProgress) => {
                logger.info(`[${preset.name}] Processing: ${progress.percent?.toFixed(2)}% done`);
            })
            .on('end', () => resolve())
            .on('error', (err: Error) => reject(err))
            .run();
    });
    
    return playlistName;
}

export const processVideoToHLS = onObjectFinalized({
    memory: "2GiB",
    timeoutSeconds: 540,
    minInstances: 0,
    maxInstances: 3,
    cpu: 2
}, async (event: StorageEvent) => {
    const object: StorageObject = event.data;
    
    // Debug log
    logger.info('🎬 Starting HLS generation for:', object.name);

    if (!object.name) {
        logger.error('❌ No object name provided');
        return;
    }

    // Only process video files in the videos folder
    if (!object.name.startsWith('videos/') || !object.contentType?.includes('video')) {
        logger.info('⏭️ Skipping non-video file or file not in videos folder');
        return;
    }

    // Skip processing if this is already an HLS file
    if (object.name.includes('hls/')) {
        logger.info('⏭️ Skipping HLS file');
        return;
    }

    const bucket = storage.bucket(BUCKET_NAME);
    const filePath = object.name;
    const fileName = path.basename(filePath);
    const workingDir = path.join(os.tmpdir(), 'hls', fileName);
    const videoPath = path.join(workingDir, 'source.mp4');
    const outputPath = path.join(workingDir, 'output');

    try {
        // Create working directory
        await fs.promises.mkdir(workingDir, { recursive: true });
        await fs.promises.mkdir(outputPath, { recursive: true });

        logger.info('📥 Downloading source video...');
        // Download the video file
        await bucket.file(filePath).download({
            destination: videoPath
        });

        logger.info('🎯 Starting HLS conversion...');
        // Generate HLS for each quality preset
        const variants: string[] = [];
        
        for (const preset of QUALITY_PRESETS) {
            logger.info(`🔄 Processing ${preset.name} variant...`);
            const playlistName = await transcodeToHLS(videoPath, outputPath, preset);
            variants.push(playlistName);
        }

        // Generate master playlist
        await generateVariantPlaylist(outputPath, variants);

        logger.info('📤 Uploading HLS files...');
        // Upload HLS files
        const hlsPath = path.join('hls', fileName);
        const files = await fs.promises.readdir(outputPath, { recursive: true });
        
        for (const file of files) {
            const localFilePath = path.join(outputPath, file);
            const remoteFilePath = path.join(hlsPath, file);
            
            // Skip if it's a directory
            if ((await fs.promises.stat(localFilePath)).isDirectory()) continue;
            
            await bucket.upload(localFilePath, {
                destination: remoteFilePath,
                metadata: {
                    contentType: file.endsWith('.m3u8') ? 'application/x-mpegURL' : 'video/MP2T',
                    cacheControl: 'public, max-age=31536000' // Cache for 1 year
                }
            });
        }

        // Update video document in Firestore with HLS URL
        const hlsUrl = `https://storage.googleapis.com/${BUCKET_NAME}/${hlsPath}/master.m3u8`;
        const videoId = path.parse(fileName).name;
        
        await admin.firestore()
            .collection('videos')
            .doc(videoId)
            .update({
                hlsUrl: hlsUrl,
                status: 'processed',
                qualities: QUALITY_PRESETS.map(p => p.name)
            });

        logger.info('✅ HLS generation completed successfully');

        // Cleanup
        await fs.promises.rm(workingDir, { recursive: true, force: true });

    } catch (error: unknown) {
        logger.error('❌ Error generating HLS:', error);
        
        // Update video status to failed
        const videoId = path.parse(fileName).name;
        await admin.firestore()
            .collection('videos')
            .doc(videoId)
            .update({
                status: 'failed',
                error: error instanceof Error ? error.message : 'Unknown error occurred'
            });
            
        throw error;
    }
});
