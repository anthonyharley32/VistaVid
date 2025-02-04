Below is an example of a detailed Product Requirements Document (PRD) that you can share with your engineering team. It’s structured to cover the core functionalities first (features 1–7) and then outlines the future AI enhancements (features 8–10). The document is written with explicit details on dependencies, variable names, API endpoints, data models, and overall flows.

---

# VistaVid PRD

## 1. Project Overview

**VistaVid** is a short-form video-sharing app—a TikTok clone with added layers such as algorithm accountability, business analytics, and community interactions. The app will eventually incorporate AI features (gesture-based controls, content moderation, AI-enhanced search) but the MVP will focus on the following core functionalities:

1. User Authentication/Management  
2. Video Feed & Playback  
3. Basic Content Creation & Upload  
4. Engagement Features (Likes, Comments, Shares, Follow/Unfollow)  
5. Algorithm Accountability (user-selected curation filters)  
6. Business Algorithm (for business accounts with additional trend analytics)  
7. Communities  

**Tech Stack:**

- **Frontend:** Swift (UIKit or SwiftUI), AVFoundation for video capture, CoreML (for later AI features)
- **Backend:** Firebase (Authentication, Firestore [NoSQL] for real-time data, and Firebase Storage for video assets)

---

## 2. Features

### 2.1. User Authentication/Management
- **What:** Users sign up, log in, and manage their profiles.
- **Key Elements:**
  - **Signup/Login:** Using FirebaseAuth.
  - **Profile Tab:** Displays user info, settings (e.g., business account toggle, preferred algorithms).
  - **Data Storage:** User metadata stored in a Firestore collection named `users`.

### 2.2. Video Feed & Playback
- **What:** An infinite scrolling feed with smooth video playback.
- **Key Elements:**
  - **Infinite Scroll:** Load videos in batches (e.g., 10 per request) with a pagination cursor.
  - **Playback Controls:** Mute/unmute and play/pause.
  - **Data:** Video metadata in Firestore collection `videos`; actual video files stored in Firebase Storage.

### 2.3. Basic Content Creation & Upload
- **What:** In-app video recording and upload without editing.
- **Key Elements:**
  - **Recording:** Use AVFoundation to capture video.
  - **Upload:** Store the video file in Firebase Storage and then record metadata in Firestore.
  - **UI:** Recording screen with a capture button and preview window.

### 2.4. Engagement Features
- **What:** Enable user interactions—likes, comments, shares, follow/unfollow.
- **Key Elements:**
  - **Likes:** Increment a `likesCount` and (optionally) record a like document.
  - **Comments:** Stored as a subcollection under each video document.
  - **Shares:** Increment a `sharesCount` and invoke share functionality.
  - **Follow/Unfollow:** Update user relationship data in Firestore.

### 2.5. Algorithm Accountability
- **What:** Allow users to filter their feed by selecting algorithms (e.g., "AI", "Fitness", "Makeup").
- **Key Elements:**
  - **UI:** A row of filter buttons on the feed and a selection screen on the profile.
  - **Data:** Each video document contains an array `algorithmTags`.
  - **Query:** Use Firestore’s `arrayContainsAny` to filter videos based on the user’s `selectedAlgorithms`.

### 2.6. Business Algorithm
- **What:** For business users, provide trend analytics (e.g., upcoming trends with probability/confidence metrics).
- **Key Elements:**
  - **Settings:** Toggle in the profile to enable a business account (`isBusiness` flag).
  - **Data:** Videos can have an optional `businessData` object containing fields like `trendRating` and `confidenceInterval`.
  - **UI:** Additional algorithm button/filter for “Business Trends.”

### 2.7. Communities
- **What:** Users can create/join communities around interests.
- **Key Elements:**
  - **Community Creation:** Users can create communities with a name, description, etc.
  - **Membership:** Lists of member IDs are maintained.
  - **Data:** Stored in a Firestore collection named `communities`.
  - **UI:** Community list view, details view, and membership management.

### 2.8. Future AI Features (for later iterations)
- **(A) Hands Free Mode:**  
  - **Use Case:** Control video navigation via gestures (e.g., wink or eyebrow raise).
  - **Dependency:** Core ML (e.g., `GestureDetector.mlmodel`).

- **(B) Content Moderation:**  
  - **Use Case:** Automatically flag explicit or copyrighted content.
  - **Dependency:** Core ML and a moderation model (e.g., `ContentModerator.mlmodel`).

- **(C) AI-enhanced Search:**  
  - **Use Case:** Search videos using AI-generated embeddings from video content and transcripts.
  - **Dependency:** Core ML model for embeddings (e.g., `SearchEmbedder.mlmodel`).

---

## 3. Requirements for Each Feature

### 3.1. User Authentication/Management
- **Dependencies:**  
  - FirebaseAuth, Firestore, FirebaseStorage (for profile images)
- **Flow:**
  1. **Signup:**  
     - **Input:** `email`, `password`, `username`, optionally a `profilePicData` (Base64 string).  
     - **Process:** Create user in FirebaseAuth; store metadata in Firestore `users` collection.  
     - **Variable Names:** `userId`, `username`, `email`, `profilePicUrl`, `createdAt`, `isBusiness` (default: false), `selectedAlgorithms` (default: empty array).
  2. **Login:**  
     - **Input:** `email`, `password`.  
     - **Process:** Authenticate via FirebaseAuth; retrieve user metadata.
  3. **Profile Tab:**  
     - Display and allow editing of user details and settings.
- **Error Handling:**  
  - Invalid credentials, network failures, duplicate usernames/emails.

### 3.2. Video Feed & Playback
- **Dependencies:**  
  - AVPlayer for video playback, Firestore for real-time data.
- **Flow:**
  1. **Load Videos:**  
     - Query Firestore collection `videos` ordered by `createdAt` (descending) with a limit (e.g., 10).  
     - Use `lastVisible` for pagination.
  2. **Playback:**  
     - Display each video in a cell with play/pause and mute/unmute controls.
- **Variable Names:**  
  - Each video document has `videoId`, `userId`, `videoUrl`, `thumbnailUrl`, `description`, `likesCount`, `commentsCount`, `sharesCount`, `createdAt`, and `algorithmTags`.
- **Error Handling:**  
  - Handle network errors and playback interruptions.

### 3.3. Basic Content Creation & Upload
- **Dependencies:**  
  - AVFoundation for video recording, FirebaseStorage for uploads, Firestore for metadata.
- **Flow:**
  1. **Recording:**  
     - Record using an in-app recorder. Save as a temporary file (`localVideoFilePath`).
  2. **Uploading:**  
     - Upload video file to Firebase Storage.  
     - On success, retrieve the `uploadedVideoUrl` and optionally generate a `thumbnailUrl`.  
     - Create a document in the `videos` collection with the relevant metadata.
- **Error Handling:**  
  - Handle file I/O errors and network failures during upload.

### 3.4. Engagement Features
- **Dependencies:**  
  - Firestore for real-time updates.
- **Flow:**
  1. **Like:**  
     - On tapping the like button, send a request to increment the `likesCount` and optionally add a record in a `likes` subcollection.
  2. **Comment:**  
     - Users post a comment which is stored in a subcollection under the corresponding video (`videos/{videoId}/comments`).
  3. **Share:**  
     - Tapping share increments the `sharesCount` and triggers native share options.
  4. **Follow/Unfollow:**  
     - Update follow relationship records (could be maintained as subcollections on the user document or in a dedicated collection).
- **Variable Names:**  
  - For comments: `commentId`, `userId`, `content`, `createdAt`, `parentCommentId` (optional).  
  - For likes: `likeId`, `userId`, `createdAt`.
- **Error Handling:**  
  - Duplicate likes, comment validation, and proper relationship management.

### 3.5. Algorithm Accountability
- **Dependencies:**  
  - Firestore query capabilities; UI controls in Swift.
- **Flow:**
  1. **User Selection:**  
     - On the profile settings page, allow users to select their preferred algorithms (e.g., "AI", "Fitness", "Makeup").  
     - Save these in the `selectedAlgorithms` field in the user document.
  2. **Feed Filtering:**  
     - Display a row of buttons (algorithm filters) on the feed screen.
     - When selected, query videos using:  
       ```swift
       Firestore.collection("videos")
           .whereField("algorithmTags", arrayContainsAny: selectedAlgorithms)
       ```
- **Variable Names:**  
  - In video documents: `algorithmTags` (array of strings).  
  - In user documents: `selectedAlgorithms` (array of strings).

### 3.6. Business Algorithm
- **Dependencies:**  
  - Firebase settings, Firestore.
- **Flow:**
  1. **Enable Business Account:**  
     - In the profile settings, the user toggles `isBusiness` to true.
  2. **Display Business Trends:**  
     - For business accounts, add a business algorithm filter (e.g., “Business Trends”) to the feed.
     - Videos may include an optional object `businessData` with keys such as:  
       - `trendRating`: Number  
       - `confidenceInterval`: String (e.g., `"95% CI: [0.90, 0.98]"`)
- **Variable Names:**  
  - User: `isBusiness` (Boolean).  
  - Video: `businessData` (Dictionary/Object).

### 3.7. Communities
- **Dependencies:**  
  - Firestore for data storage.
- **Flow:**
  1. **Community Creation:**  
     - Allow users to create a community with a name and description.
  2. **Joining/Leaving:**  
     - Users can join or leave communities. Membership is maintained as an array of `userId`s in each community document.
  3. **Community Feed:**  
     - Optionally, each community can have its own feed (either as a subcollection or as a field linking to relevant videos).
- **Variable Names:**  
  - Community document: `communityId`, `name`, `description`, `createdAt`, `members` (array), `moderators` (array).
- **Error Handling:**  
  - Handle duplicate community names and validate membership actions.

### 3.8. Future AI Features (High-Level Requirements)
- **Hands Free Mode:**  
  - Integrate an Core ML module (e.g., a custom model named `GestureDetector.mlmodel`) in the video playback view to listen for gestures (wink, eyebrow raise) and trigger actions (e.g., next video).
- **Content Moderation:**  
  - On video upload, run the content through an on-device CoreML model (e.g., `ContentModerator.mlmodel`) to flag explicit or copyrighted material.
- **AI-enhanced Search:**  
  - Generate embeddings for video content and transcripts using a model (e.g., `SearchEmbedder.mlmodel`) and allow users to search by similarity.
- **Note:**  
  - These will be implemented only after core features are stable.

---

## 4. Data Models

### 4.1. User Model (Firestore Collection: `users`)
```json
{
  "userId": "String",          // FirebaseAuth.uid
  "username": "String",
  "email": "String",
  "profilePicUrl": "String",   // URL stored in Firebase Storage
  "createdAt": "Timestamp",
  "isBusiness": "Boolean",     // Default false
  "selectedAlgorithms": ["String"] // e.g., ["AI", "Fitness"]
}
```

### 4.2. Video Model (Firestore Collection: `videos`)
```json
{
  "videoId": "String",         // Unique identifier
  "userId": "String",          // Owner's userId
  "videoUrl": "String",        // URL from Firebase Storage
  "thumbnailUrl": "String",    // URL for video thumbnail
  "description": "String",
  "likesCount": "Number",
  "commentsCount": "Number",
  "sharesCount": "Number",
  "createdAt": "Timestamp",
  "algorithmTags": ["String"], // e.g., ["AI", "Makeup"]
  "businessData": {            // Optional: only for business videos
    "trendRating": "Number",
    "confidenceInterval": "String"  // e.g., "95% CI: [0.90, 0.98]"
  }
}
```

### 4.3. Comment Model (Subcollection: `videos/{videoId}/comments`)
```json
{
  "commentId": "String",
  "userId": "String",
  "content": "String",
  "createdAt": "Timestamp",
  "parentCommentId": "String"  // Optional for threaded replies
}
```

### 4.4. Like Model
- **Option 1:** Use a subcollection under each video (`videos/{videoId}/likes`).
- **Option 2:** Store like counts and a mapping in the user document.
```json
{
  "likeId": "String",  // Optional, if storing each like as a document
  "userId": "String",
  "createdAt": "Timestamp"
}
```

### 4.5. Community Model (Firestore Collection: `communities`)
```json
{
  "communityId": "String",
  "name": "String",
  "description": "String",
  "createdAt": "Timestamp",
  "members": ["String"],    // Array of userIds
  "moderators": ["String"]   // Array of userIds
}
```

---

## 5. API Contract

> **Note:** Although Firebase allows direct client-side access to Firestore and Storage, encapsulating certain operations in Cloud Functions (or similar server-side endpoints) is recommended for business logic and security. Below are sample API endpoints to define the contract.

### 5.1. Authentication Endpoints

#### **Signup**
- **Endpoint:** `POST /auth/signup`
- **Request Body:**
  ```json
  {
    "email": "string",
    "password": "string",
    "username": "string",
    "profilePicData": "Base64EncodedString"  // Optional
  }
  ```
- **Response:**
  ```json
  {
    "success": true,
    "userId": "string"
  }
  ```
- **Notes:**  
  - Create the user via FirebaseAuth.
  - Store user metadata in the `users` collection.

#### **Login**
- **Endpoint:** `POST /auth/login`
- **Request Body:**
  ```json
  {
    "email": "string",
    "password": "string"
  }
  ```
- **Response:**
  ```json
  {
    "success": true,
    "userId": "string",
    "token": "FirebaseAuthToken"
  }
  ```

### 5.2. Video Feed & Playback

#### **Get Videos (Infinite Scroll)**
- **Endpoint:** `GET /videos`
- **Query Parameters:**
  - `limit` (default: 10)
  - `lastVisible` (cursor for pagination, optional)
  - `algorithmFilter` (optional, comma-separated values)
- **Response:**
  ```json
  {
    "videos": [
      {
        "videoId": "string",
        "userId": "string",
        "videoUrl": "string",
        "thumbnailUrl": "string",
        "description": "string",
        "likesCount": 0,
        "commentsCount": 0,
        "sharesCount": 0,
        "createdAt": "timestamp",
        "algorithmTags": ["string"],
        "businessData": { /* if applicable */ }
      }
      // ... more videos
    ],
    "lastVisible": "string"  // For pagination
  }
  ```
- **Firestore Query Example:**
  ```swift
  let query = Firestore.firestore().collection("videos")
      .order(by: "createdAt", descending: true)
      .limit(to: limit)
  if let filter = algorithmFilter {
      query.whereField("algorithmTags", arrayContainsAny: filterArray)
  }
  ```

### 5.3. Content Creation & Upload

#### **Upload Video**
- **Endpoint:** `POST /video/upload`
- **Request:** Multipart/form-data including:
  - `videoFile`: binary video data
  - `thumbnail`: (optional) binary data (or auto-generate on upload)
  - `description`: string
  - `algorithmTags`: array of strings (e.g., `["AI", "Fitness"]`)
- **Response:**
  ```json
  {
    "success": true,
    "videoId": "string"
  }
  ```
- **Flow:**
  1. Upload the video file to Firebase Storage.
  2. Retrieve the `videoUrl` and (if needed) `thumbnailUrl`.
  3. Create a new document in the `videos` collection with the metadata.

### 5.4. Engagement Endpoints

#### **Like Video**
- **Endpoint:** `POST /video/{videoId}/like`
- **Request Body:**
  ```json
  {
    "userId": "string"
  }
  ```
- **Response:**
  ```json
  {
    "success": true,
    "likesCount": 101
  }
  ```

#### **Comment on Video**
- **Endpoint:** `POST /video/{videoId}/comment`
- **Request Body:**
  ```json
  {
    "userId": "string",
    "content": "string",
    "parentCommentId": "string"  // Optional
  }
  ```
- **Response:**
  ```json
  {
    "success": true,
    "commentId": "string"
  }
  ```

#### **Follow/Unfollow**
- **Follow:**  
  - **Endpoint:** `POST /user/{targetUserId}/follow`
  - **Request Body:**
    ```json
    {
      "followerId": "string"
    }
    ```
  - **Response:**
    ```json
    {
      "success": true
    }
    ```
- **Unfollow:**  
  - **Endpoint:** `POST /user/{targetUserId}/unfollow`
  - **Request Body:**
    ```json
    {
      "followerId": "string"
    }
    ```
  - **Response:**
    ```json
    {
      "success": true
    }
    ```

### 5.5. Communities Endpoints

#### **Get Communities**
- **Endpoint:** `GET /communities`
- **Response:**
  ```json
  {
    "communities": [
      {
        "communityId": "string",
        "name": "string",
        "description": "string",
        "members": ["userId1", "userId2"]
      }
      // ... more communities
    ]
  }
  ```

#### **Create Community**
- **Endpoint:** `POST /communities`
- **Request Body:**
  ```json
  {
    "name": "string",
    "description": "string",
    "creatorId": "string"
  }
  ```
- **Response:**
  ```json
  {
    "success": true,
    "communityId": "string"
  }
  ```

#### **Join/Leave Community**
- **Join:**  
  - **Endpoint:** `POST /communities/{communityId}/join`
  - **Request Body:**
    ```json
    {
      "userId": "string"
    }
    ```
  - **Response:**
    ```json
    {
      "success": true
    }
    ```
- **Leave:**  
  - **Endpoint:** `POST /communities/{communityId}/leave`
  - **Request Body:**
    ```json
    {
      "userId": "string"
    }
    ```
  - **Response:**
    ```json
    {
      "success": true
    }
    ```

### 5.6. Business Algorithm Endpoints

#### **Update Business Account Settings**
- **Endpoint:** `PUT /user/{userId}/settings`
- **Request Body:**
  ```json
  {
    "isBusiness": true,
    "selectedAlgorithms": ["AI", "Business", "Fitness"]
  }
  ```
- **Response:**
  ```json
  {
    "success": true
  }
  ```

> **Note:** The AI features (hands-free mode, content moderation, AI-enhanced search) will primarily integrate on the client side using Core ML models. If further server-side processing is needed, we will add Cloud Function endpoints later.

---

## 6. Dependencies & Additional Notes

- **Firebase SDKs:**  
  - FirebaseAuth  
  - Firestore  
  - FirebaseStorage
- **Swift Frameworks:**  
  - UIKit/SwiftUI  
  - AVFoundation  
  - CoreML
- **Third-Party Libraries:**  
  - Consider using SDWebImage (or similar) for image caching.
- **Development Tools:**  
  - Swift 5.x  
  - Xcode 14+  
  - Follow SwiftLint for code style.
- **Versioning:**  
  - Use Git for source control with feature branching for each module.
- **Testing:**  
  - Unit tests for business logic, integration tests for Firebase interactions, and UI tests for feed and engagement functionalities.

---

This PRD lays out a clear, unambiguous roadmap for building VistaVid. It details the data models, API contracts (even though much of the client–Firebase interaction is direct), variable names, and flows for each feature. Once the core 7 features are stable, the engineering team can move on to integrating the AI-based enhancements.