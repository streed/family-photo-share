# Image Processing System

This document describes the background image processing system implemented using Sidekiq to create thumbnails in various sizes for improved bandwidth usage and page load speed.

## Overview

The system automatically processes uploaded images in the background to generate multiple thumbnail sizes:

- **thumbnail**: 200x200px (85% quality) - For grid views, lists
- **small**: 400x400px (90% quality) - For small displays
- **medium**: 600x600px (90% quality) - For medium displays  
- **large**: 1200x1200px (90% quality) - For detailed views
- **xl**: 1920x1920px (90% quality) - For full-screen displays

## Architecture

### Components

1. **ImageProcessingJob** (`app/jobs/image_processing_job.rb`)
   - Sidekiq job that processes individual photos
   - Queued automatically when photos are uploaded
   - Retry logic: 3 attempts, uses `image_processing` queue

2. **ImageProcessingService** (`app/services/image_processing_service.rb`)
   - Core service for generating image variants
   - Handles analysis and variant processing
   - Provides methods for checking processing status

3. **Photo Model Updates** (`app/models/photo.rb`)
   - Enhanced with new variant methods
   - `best_variant(size)` - Returns best available variant with fallback
   - Status checking methods for processing completion

4. **Helper Methods** (`app/helpers/image_processing_helper.rb`)
   - View helpers for responsive images
   - Error handling and fallback mechanisms
   - Status badges for processing progress

## Usage

### Automatic Processing

When a photo is uploaded, processing is automatically triggered:

```ruby
# In Photo model after_create_commit callback
def process_image_variants
  ImageProcessingJob.perform_async(id)
end
```

### Manual Processing

```bash
# Process all unprocessed images
rails images:process_all

# Check processing status
rails images:status

# Reprocess specific photo
rails images:reprocess[123]

# Clean up stale processing jobs
rails images:cleanup
```

### In Views

Use the enhanced methods for optimal image loading:

```erb
<!-- Best available variant with fallback -->
<%= image_tag photo.best_variant(:medium), alt: photo.title %>

<!-- Responsive image with multiple sizes -->
<%= responsive_image_tag photo, { small: :thumbnail, large: :medium } %>

<!-- Processing status badge -->
<%= processing_status_badge(photo) %>
```

### Available Photo Methods

```ruby
# New variant methods
photo.thumbnail    # 200x200
photo.small       # 400x400  
photo.medium      # 600x600
photo.large       # 1200x1200
photo.xl          # 1920x1920

# Best available variant (with fallback to smaller sizes)
photo.best_variant(:large)

# Status checks
photo.background_processing_complete?
photo.all_variants_ready?
```

## Fallback Strategy

The system implements intelligent fallbacks:

1. **Requested size**: Try to serve the exact size requested
2. **Smaller variants**: Fall back to progressively smaller sizes if requested size isn't ready
3. **Original image**: Use original as last resort
4. **Error handling**: Graceful degradation with placeholder images

## Queue Configuration

Add to your `config/sidekiq.yml`:

```yaml
queues:
  - image_processing
  - bulk_processing
  - default
```

## Monitoring

### Processing Status

Check individual photo status:
```ruby
photo.processing_completed_at  # Timestamp when processing finished
photo.all_variants_ready?      # True if all variants are processed
```

### System Status

```bash
rails images:status
```

Output:
```
Image Processing Status:
==============================
Total photos: 150
Processed: 147
Unprocessed: 3
Progress: 98.0%
```

## Performance Benefits

1. **Reduced Bandwidth**: Serve appropriately sized images
2. **Faster Page Loads**: Smaller images load faster
3. **Better UX**: Images appear quickly with progressive enhancement
4. **Background Processing**: No delay in upload workflow
5. **Responsive Design**: Optimal images for different screen sizes

## Error Handling

The system includes comprehensive error handling:

- **Job Retries**: Failed jobs retry up to 3 times
- **Graceful Degradation**: Falls back to smaller variants or original
- **Logging**: Detailed logs for debugging
- **Status Tracking**: Clear processing status indicators

## Migration

For existing photos, run the bulk processing task:

```bash
rails images:process_all
```

This will:
1. Identify unprocessed photos
2. Queue them for background processing in batches
3. Automatically continue until all photos are processed

## Troubleshooting

### Common Issues

1. **Sidekiq not running**: Ensure Sidekiq is running with `bundle exec sidekiq`
2. **Queue backed up**: Check Sidekiq web UI at `/sidekiq` (development only)
3. **Failed jobs**: Check Sidekiq failed queue and retry or debug
4. **Missing variants**: Use `rails images:reprocess[photo_id]` to reprocess specific photos

### Logs

Processing logs are written to Rails logger:
```
Starting image processing for Photo 123
Processed thumbnail variant for Photo 123 in 0.34s
Processed medium variant for Photo 123 in 0.67s
Completed image processing for Photo 123
```

## Configuration

The thumbnail sizes are configured in `ImageProcessingService::THUMBNAIL_SIZES`. To modify sizes, update this constant and reprocess existing images.

## Security Considerations

- Images are processed server-side using secure libraries
- No user input directly affects image processing parameters
- Original files are preserved
- Variants are generated with safe, predefined parameters