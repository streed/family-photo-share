# Family Photo Share API Documentation

This document describes the internal API endpoints used by the Family Photo Share application.

## Table of Contents

- [Authentication](#authentication)
- [Photos API](#photos-api)
- [Albums API](#albums-api)
- [Bulk Uploads API](#bulk-uploads-api)
- [External Albums API](#external-albums-api)
- [Families API](#families-api)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)

## Authentication

The application uses session-based authentication with Devise. All API endpoints require authentication unless specified otherwise.

### Login
```http
POST /users/sign_in
Content-Type: application/x-www-form-urlencoded

user[email]=user@example.com&user[password]=password
```

### Logout
```http
DELETE /users/sign_out
```

### Rate Limiting

Login attempts are rate-limited to prevent brute force attacks:
- Maximum 5 failed attempts per session
- 15-minute lockout after exceeding limit
- Progressive error messages showing remaining attempts

## Photos API

### List Photos
```http
GET /photos
```

**Response:**
```json
{
  "photos": [
    {
      "id": 1,
      "title": "Sunset Beach",
      "description": "Beautiful sunset at the beach",
      "taken_at": "2024-01-15T18:30:00Z",
      "latitude": 40.7128,
      "longitude": -74.0060,
      "camera_make": "Canon",
      "camera_model": "EOS R5",
      "user": {
        "id": 1,
        "name": "John Doe"
      },
      "urls": {
        "thumbnail": "/rails/active_storage/...",
        "large": "/rails/active_storage/..."
      }
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 25
  }
}
```

### Upload Photo
```http
POST /photos
Content-Type: multipart/form-data

photo[image]=<file>
photo[title]=My Photo
photo[description]=A beautiful photo
```

**Response:**
```json
{
  "photo": {
    "id": 42,
    "title": "My Photo",
    "description": "A beautiful photo",
    "processing_status": "pending"
  }
}
```

### Get Photo
```http
GET /photos/:id
```

**Response:**
```json
{
  "photo": {
    "id": 1,
    "title": "Sunset Beach",
    "description": "Beautiful sunset at the beach",
    "taken_at": "2024-01-15T18:30:00Z",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "camera_make": "Canon",
    "camera_model": "EOS R5",
    "metadata": {
      "ISO": "100",
      "FNumber": "2.8",
      "ExposureTime": "1/250"
    },
    "user": {
      "id": 1,
      "name": "John Doe"
    },
    "albums": [
      {
        "id": 1,
        "name": "Beach Vacation"
      }
    ],
    "urls": {
      "thumbnail": "/rails/active_storage/...",
      "large": "/rails/active_storage/...",
      "original": "/rails/active_storage/..."
    }
  }
}
```

### Update Photo
```http
PATCH /photos/:id
Content-Type: application/json

{
  "photo": {
    "title": "Updated Title",
    "description": "Updated description"
  }
}
```

### Delete Photo
```http
DELETE /photos/:id
```

**Response:**
```json
{
  "message": "Photo deleted successfully"
}
```

## Albums API

### List Albums
```http
GET /albums
```

**Query Parameters:**
- `privacy`: Filter by privacy level (`private`, `family`, `external`)

**Response:**
```json
{
  "albums": [
    {
      "id": 1,
      "name": "Beach Vacation",
      "description": "Our summer vacation photos",
      "privacy": "family",
      "photo_count": 25,
      "cover_photo": {
        "id": 5,
        "thumbnail_url": "/rails/active_storage/..."
      },
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T12:00:00Z"
    }
  ]
}
```

### Create Album
```http
POST /albums
Content-Type: application/json

{
  "album": {
    "name": "My New Album",
    "description": "Description of the album",
    "privacy": "family",
    "allow_external_access": false,
    "password": "optional-password"
  }
}
```

### Get Album
```http
GET /albums/:id
```

**Response:**
```json
{
  "album": {
    "id": 1,
    "name": "Beach Vacation",
    "description": "Our summer vacation photos",
    "privacy": "family",
    "allow_external_access": true,
    "sharing_url": "https://example.com/external_albums/abc123",
    "photos": [
      {
        "id": 1,
        "title": "Sunset Beach",
        "thumbnail_url": "/rails/active_storage/..."
      }
    ],
    "cover_photo": {
      "id": 5,
      "thumbnail_url": "/rails/active_storage/..."
    }
  }
}
```

### Update Album
```http
PATCH /albums/:id
Content-Type: application/json

{
  "album": {
    "name": "Updated Album Name",
    "description": "Updated description",
    "privacy": "private"
  }
}
```

### Delete Album
```http
DELETE /albums/:id
```

### Add Photo to Album
```http
PATCH /albums/:id/add_photo
Content-Type: application/json

{
  "photo_id": 42
}
```

### Remove Photo from Album
```http
DELETE /albums/:id/remove_photo
Content-Type: application/json

{
  "photo_id": 42
}
```

### Set Cover Photo
```http
PATCH /albums/:id/set_cover
Content-Type: application/json

{
  "photo_id": 42
}
```

## Bulk Uploads API

### Create Bulk Upload Session
```http
POST /bulk_uploads
Content-Type: application/json

{
  "bulk_upload": {
    "name": "Family Reunion Photos"
  }
}
```

**Response:**
```json
{
  "bulk_upload": {
    "id": 1,
    "name": "Family Reunion Photos",
    "status": "pending",
    "upload_token": "abc123def456"
  }
}
```

### Add Photos to Bulk Upload
```http
POST /bulk_uploads/:id/photos
Content-Type: multipart/form-data

photos[]=<file1>
photos[]=<file2>
photos[]=<file3>
```

**Response:**
```json
{
  "added_photos": 3,
  "failed_photos": 0,
  "total_photos": 3,
  "bulk_upload": {
    "id": 1,
    "status": "uploading"
  }
}
```

### Process Bulk Upload
```http
POST /bulk_uploads/:id/process
```

**Response:**
```json
{
  "bulk_upload": {
    "id": 1,
    "status": "processing",
    "job_id": "def456abc789"
  }
}
```

### Get Bulk Upload Status
```http
GET /bulk_uploads/:id/status
```

**Response:**
```json
{
  "bulk_upload": {
    "id": 1,
    "name": "Family Reunion Photos",
    "status": "completed",
    "total_photos": 50,
    "processed_photos": 50,
    "failed_photos": 0,
    "progress_percentage": 100,
    "completed_at": "2024-01-15T14:30:00Z"
  }
}
```

## External Albums API

### View External Album (No Auth Required)
```http
GET /external_albums/:sharing_token
```

**Response:**
```json
{
  "album": {
    "id": 1,
    "name": "Beach Vacation",
    "description": "Our summer vacation photos",
    "photos": [
      {
        "id": 1,
        "title": "Sunset Beach",
        "thumbnail_url": "/rails/active_storage/...",
        "large_url": "/rails/active_storage/..."
      }
    ],
    "requires_password": false
  }
}
```

### Authenticate External Album
```http
POST /external_albums/:sharing_token/authenticate
Content-Type: application/json

{
  "password": "album-password"
}
```

**Response:**
```json
{
  "success": true,
  "session_token": "xyz789abc123",
  "expires_at": "2024-01-16T00:00:00Z"
}
```

## Families API

### Get Family Information
```http
GET /families/:id
```

**Response:**
```json
{
  "family": {
    "id": 1,
    "name": "Smith Family",
    "members": [
      {
        "id": 1,
        "name": "John Smith",
        "email": "john@example.com",
        "role": "admin"
      },
      {
        "id": 2,
        "name": "Jane Smith",
        "email": "jane@example.com",
        "role": "member"
      }
    ]
  }
}
```

### Invite Family Member
```http
POST /families/:id/invite
Content-Type: application/json

{
  "email": "newmember@example.com",
  "role": "member"
}
```

## Error Handling

The API uses standard HTTP status codes and returns structured error responses:

### Success Codes
- `200 OK` - Request succeeded
- `201 Created` - Resource created successfully
- `204 No Content` - Request succeeded with no response body

### Error Codes
- `400 Bad Request` - Invalid request parameters
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Access denied
- `404 Not Found` - Resource not found
- `422 Unprocessable Entity` - Validation errors
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server error

### Error Response Format
```json
{
  "error": {
    "code": "validation_failed",
    "message": "The request could not be processed",
    "details": {
      "title": ["can't be blank"],
      "image": ["must be a valid image file"]
    }
  }
}
```

### Common Error Codes
- `authentication_required` - User must be logged in
- `access_denied` - User lacks permission for this resource
- `validation_failed` - Request data failed validation
- `resource_not_found` - Requested resource doesn't exist
- `rate_limit_exceeded` - Too many requests in time period
- `file_too_large` - Uploaded file exceeds size limit
- `invalid_file_type` - Uploaded file type not supported

## Rate Limiting

### Authentication Rate Limits
- Login attempts: 5 per session per 15 minutes
- Password reset: 3 per email per hour
- Account creation: 5 per IP per hour

### API Rate Limits
- Photo uploads: 100 per user per hour
- Album operations: 200 per user per hour
- Bulk uploads: 5 per user per hour

### Rate Limit Headers
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1642694400
```

## Webhooks (Future Feature)

The API will support webhooks for real-time notifications:

### Supported Events
- `photo.uploaded` - New photo uploaded
- `photo.processed` - Photo processing completed
- `album.created` - New album created
- `album.shared` - Album shared externally
- `bulk_upload.completed` - Bulk upload finished

### Webhook Payload Example
```json
{
  "event": "photo.uploaded",
  "timestamp": "2024-01-15T12:00:00Z",
  "data": {
    "photo": {
      "id": 42,
      "title": "New Photo",
      "user_id": 1
    }
  }
}
```

## SDK and Client Libraries

### Ruby Client
```ruby
gem 'family_photo_share_client'

client = FamilyPhotoShare::Client.new(
  host: 'https://your-instance.com',
  session_token: 'your-session-token'
)

photos = client.photos.list
photo = client.photos.upload(file: File.open('photo.jpg'))
```

### JavaScript Client
```javascript
import FamilyPhotoShareClient from 'family-photo-share-client';

const client = new FamilyPhotoShareClient({
  host: 'https://your-instance.com',
  sessionToken: 'your-session-token'
});

const photos = await client.photos.list();
const photo = await client.photos.upload(file);
```

## Testing the API

### Using curl

```bash
# Login
curl -X POST https://your-instance.com/users/sign_in \
  -d "user[email]=test@example.com&user[password]=password" \
  -c cookies.txt

# Upload photo
curl -X POST https://your-instance.com/photos \
  -b cookies.txt \
  -F "photo[image]=@test.jpg" \
  -F "photo[title]=Test Photo"

# List albums
curl -X GET https://your-instance.com/albums \
  -b cookies.txt \
  -H "Accept: application/json"
```

### Using Postman

Import the [Postman collection](postman_collection.json) for easy API testing.

---

For more information about the API, see the [source code](../app/controllers/) and [tests](../spec/requests/).