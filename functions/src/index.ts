/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import * as functions from 'firebase-functions/v1';
import { DocumentSnapshot } from 'firebase-functions/v1/firestore';
import { ObjectMetadata } from 'firebase-functions/v1/storage';
import * as logger from "firebase-functions/logger";
import * as admin from 'firebase-admin';
import * as path from 'path';
import * as os from 'os';
import * as fs from 'fs';
import ffmpeg from 'fluent-ffmpeg';
import * as ffmpegInstaller from '@ffmpeg-installer/ffmpeg';
import { Storage } from '@google-cloud/storage';
import fetch from 'node-fetch';

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

// Runtime configuration for long-running tasks
const runtimeOpts = {
    timeoutSeconds: 540,
    memory: '2GB'
} as const;

// Constants
const BUCKET_NAME = 'vistavid-be.firebasestorage.app';
const HLS_SEGMENT_DURATION = 6;
const FRAME_INTERVAL = 1;
const NSFW_THRESHOLD = 0.5;

// Video quality presets
const QUALITY_PRESETS = [
    { name: '1080p', height: 1080, bitrate: '5000k' },
    { name: '720p', height: 720, bitrate: '2800k' },
    { name: '480p', height: 480, bitrate: '1400k' },
    { name: '360p', height: 360, bitrate: '800k' }
];

interface FFmpegProgress {
    frames: number;
    currentFps: number;
    currentKbps: number;
    targetSize: number;
    timemark: string;
    percent?: number;
}

// Helper function to extract frames from video
async function extractFrames(videoPath: string, outputDir: string): Promise<string[]> {
    // @ts-ignore - frameFiles is used in the async context
    const frameFiles: string[] = [];
    
    await new Promise<void>((resolve, reject) => {
        ffmpeg(videoPath)
            .outputOptions([
                `-vf fps=1/${FRAME_INTERVAL}` // Extract 1 frame every FRAME_INTERVAL seconds
            ])
            .output(path.join(outputDir, 'frame-%d.jpg'))
            .on('end', () => resolve())
            .on('error', (err: Error) => reject(err))
            .run();
    });

    // Get list of generated frame files
    const files = await fs.promises.readdir(outputDir);
    return files.filter(f => f.startsWith('frame-')).map(f => path.join(outputDir, f));
}

// Helper function to check frame for NSFW content
async function checkFrameContent(framePath: string): Promise<number> {
    const imageData = await fs.promises.readFile(framePath);
    const base64Image = imageData.toString('base64');
    const maxRetries = 5;
    const initialWaitTime = 5000; // 5 seconds

    for (let attempt = 0; attempt < maxRetries; attempt++) {
        logger.info(`🌐 Sending request to Hugging Face API for frame: ${path.basename(framePath)} (attempt ${attempt + 1}/${maxRetries})`);
        
        const response = await fetch(functions.config().huggingface.url, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${functions.config().huggingface.key}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                inputs: {
                    image: base64Image
                }
            })
        });

        // Log the raw response
        const responseText = await response.text();
        logger.info(`📡 Raw API Response: ${responseText}`);
        
        try {
            const result = JSON.parse(responseText);
            
            // Check if model is loading
            if (result.error && result.error.includes('is currently loading')) {
                const waitTime = result.estimated_time ? (result.estimated_time * 1000) : initialWaitTime;
                logger.info(`⏳ Model is loading, waiting ${waitTime/1000} seconds before retry...`);
                await new Promise(resolve => setTimeout(resolve, waitTime));
                continue;
            }
            
            // If we get here, we have a valid response
            if (Array.isArray(result)) {
                const nsfwResult = result.find(r => r.label === "nsfw");
                const score = nsfwResult?.score || 0;
                logger.info(`🎯 Frame ${path.basename(framePath)} - Final Score: ${score.toFixed(4)}`);
                return score;
            }
            
            // If we get here, something went wrong with the response format
            logger.error(`❌ Unexpected response format: ${JSON.stringify(result)}`);
            throw new Error('Unexpected response format from API');
            
        } catch (error) {
            logger.error(`❌ Error parsing API response: ${error}`);
            if (attempt === maxRetries - 1) throw error;
        }
    }
    
    throw new Error(`Failed to get valid response after ${maxRetries} attempts`);
}

// Helper function to wait for file to be available
async function waitForFile(bucket: any, filePath: string, maxAttempts: number = 5): Promise<boolean> {
    for (let i = 0; i < maxAttempts; i++) {
        try {
            const [exists] = await bucket.file(filePath).exists();
            if (exists) {
                return true;
            }
            logger.info(`File not ready, attempt ${i + 1} of ${maxAttempts}`);
            await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds
        } catch (error) {
            logger.error(`Error checking file existence: ${error}`);
        }
    }
    return false;
}

// Content moderation function
export const moderateNewVideo = functions
    .runWith(runtimeOpts)
    .firestore
    .document('videos/{videoId}')
    .onCreate(async (snap: DocumentSnapshot) => {
        const videoData = snap.data();
        const videoId = snap.id;
        
        if (!videoData) {
            logger.error('❌ No video data found');
            return;
        }

        // Only moderate videos that are newly uploaded
        if (videoData.status !== 'uploading') {
            logger.info('⏭️ Skipping video with status:', videoData.status);
            return;
        }

        logger.info('🔍 Starting content moderation for video:', videoId);

        const bucket = storage.bucket(BUCKET_NAME);
        const filePath = `videos/${videoId}.mp4`;
        const fileName = path.basename(filePath);
        const workingDir = path.join(os.tmpdir(), 'moderation', fileName);
        const videoPath = path.join(workingDir, 'source.mp4');
        const framesDir = path.join(workingDir, 'frames');

        try {
            // Wait for file to be fully available
            logger.info('⏳ Waiting for file to be ready...');
            const isFileReady = await waitForFile(bucket, filePath);
            if (!isFileReady) {
                throw new Error('File not available after maximum retries');
            }

            // Create working directories
            await fs.promises.mkdir(workingDir, { recursive: true });
            await fs.promises.mkdir(framesDir, { recursive: true });

            logger.info('📥 Downloading source video...');
            // Download the video file
            await bucket.file(filePath).download({
                destination: videoPath
            });

            logger.info('🎯 Extracting frames...');
            const frameFiles = await extractFrames(videoPath, framesDir);

            logger.info(`📊 Starting analysis of ${frameFiles.length} frames...`);
            let maxNSFWScore = 0;
            let frameScores: number[] = [];
            
            // Check each frame
            for (const [index, framePath] of frameFiles.entries()) {
                const nsfwScore = await checkFrameContent(framePath);
                frameScores.push(nsfwScore);
                maxNSFWScore = Math.max(maxNSFWScore, nsfwScore);
                
                if (maxNSFWScore > NSFW_THRESHOLD) {
                    logger.info(`🚫 Stopping analysis - Frame ${index + 1} exceeded threshold`);
                    break; // Stop checking if we've found NSFW content
                }
            }

            // Log summary statistics
            logger.info('📈 Content Moderation Summary:');
            logger.info(`Total Frames Analyzed: ${frameScores.length}`);
            logger.info(`Maximum NSFW Score: ${maxNSFWScore.toFixed(4)}`);
            logger.info(`Average NSFW Score: ${(frameScores.reduce((a, b) => a + b, 0) / frameScores.length).toFixed(4)}`);
            logger.info(`Score Distribution: ${JSON.stringify(frameScores.map(score => score.toFixed(4)))}`);

            const videoRef = admin.firestore().collection('videos').doc(videoId);

            if (maxNSFWScore > NSFW_THRESHOLD) {
                logger.info('🚫 NSFW content detected, blocking video...');
                
                // Delete the video file
                await bucket.file(filePath).delete();
                
                // Update video document
                await videoRef.update({
                    status: 'blocked',
                    moderationScore: maxNSFWScore,
                    error: 'Content violates community guidelines'
                });
                
            } else {
                logger.info('✅ Content moderation passed');
                
                // Update video document
                await videoRef.update({
                    status: 'moderation_passed',
                    moderationScore: maxNSFWScore
                });
            }

            // Cleanup
            await fs.promises.rm(workingDir, { recursive: true, force: true });

        } catch (error: unknown) {
            logger.error('❌ Error in content moderation:', error);
            
            // Update video status to failed
            await admin.firestore()
                .collection('videos')
                .doc(videoId)
                .update({
                    status: 'moderation_failed',
                    error: error instanceof Error ? error.message : 'Unknown error occurred'
                });
            
            throw error;
        }
    });

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

// HLS processing function
export const processVideoToHLS = functions
    .runWith(runtimeOpts)
    .storage
    .object()
    .onFinalize(async (object: ObjectMetadata) => {
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
            const parsedVideoId = path.parse(fileName).name;
            
            await admin.firestore()
                .collection('videos')
                .doc(parsedVideoId)
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
            const parsedVideoId = path.parse(fileName).name;
            await admin.firestore()
                .collection('videos')
                .doc(parsedVideoId)
                .update({
                    status: 'failed',
                    error: error instanceof Error ? error.message : 'Unknown error occurred'
                });
            
            throw error;
        }
    });
