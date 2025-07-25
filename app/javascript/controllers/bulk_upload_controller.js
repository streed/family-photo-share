import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "multipleFileInput", "albumSelect",
    "stagingSummary", "stagedCount", "totalSize", "stagingBadge", "stagedCountBadge",
    "emptyState", "stagingContainer", "stagedPhotosGrid", "uploadCount",
    "uploadButton", "bulkActionsBtn",
    "uploadModal", "progressBar", "progressText", "currentFileName", 
    "uploadedCount", "totalUploadCount", "uploadErrors", "errorsList",
    "confirmModal", "confirmTitle", "confirmMessage", "confirmButton"
  ]
  
  connect() {
    this.maxFileSize = 10 * 1024 * 1024; // 10MB
    this.maxFiles = 100;
    this.validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
    
    // Store staged photos in memory with their file data
    this.stagedPhotos = [];
    this.nextPhotoId = 1;
    
    // Initialize modal (using simple show/hide instead of Bootstrap)
    this.uploadModal = {
      show: () => {
        this.uploadModalTarget.style.display = 'block';
        this.uploadModalTarget.classList.add('show');
      },
      hide: () => {
        this.uploadModalTarget.style.display = 'none';
        this.uploadModalTarget.classList.remove('show');
      }
    };
    
    this.updateUI();
  }
  
  
  addMultiplePhotos(event) {
    const files = Array.from(event.target.files);
    if (!files.length) {
      return;
    }
    
    // Check if adding these files would exceed the limit
    if (this.stagedPhotos.length + files.length > this.maxFiles) {
      alert(`You can only stage up to ${this.maxFiles} photos total. You currently have ${this.stagedPhotos.length} staged.`);
      this.multipleFileInputTarget.value = '';
      return;
    }
    
    // Filter valid files
    const validFiles = files.filter(file => this.isValidFile(file));
    const invalidFiles = files.filter(file => !this.isValidFile(file));
    
    if (invalidFiles.length > 0) {
      alert(`${invalidFiles.length} files were skipped (invalid format or too large).`);
    }
    
    if (validFiles.length === 0) {
      this.multipleFileInputTarget.value = '';
      return;
    }
    
    // Add all valid files to staging
    validFiles.forEach(file => this.addFileToStaging(file));
    this.multipleFileInputTarget.value = ''; // Clear input
  }
  
  addFileToStaging(file) {
    const photoId = `photo-${this.nextPhotoId++}`;
    
    // Create staged photo object with file data in memory
    const stagedPhoto = {
      id: photoId,
      file: file,
      filename: file.name,
      size: file.size,
      title: this.extractTitleFromFilename(file.name),
      description: '',
      previewUrl: null, // Will be set when FileReader completes
      uploadStatus: 'staged' // staged, uploading, uploaded, failed
    };
    
    // Read file data for preview
    const reader = new FileReader();
    reader.onload = (e) => {
      stagedPhoto.previewUrl = e.target.result;
      this.renderStagedPhoto(stagedPhoto);
    };
    reader.onerror = (e) => {
      console.error('FileReader error:', e);
    };
    reader.readAsDataURL(file);
    
    this.stagedPhotos.push(stagedPhoto);
    this.updateUI();
  }
  
  renderStagedPhoto(photo) {
    const photoElement = document.createElement('div');
    photoElement.className = 'staged-photo-item mb-3';
    photoElement.dataset.photoId = photo.id;
    
    photoElement.innerHTML = `
      <div class="photo-card">
        <div class="photo-row">
          <div class="photo-col-4">
            <div class="photo-preview">
              <img src="${photo.previewUrl}" alt="${photo.title || 'Photo'}" class="staged-photo-img">
              <button type="button" class="remove-photo-btn" 
                      data-action="click->bulk-upload#removePhoto" 
                      data-photo-id="${photo.id}"
                      title="Remove photo">
                ×
              </button>
            </div>
          </div>
          <div class="photo-col-8">
            <div class="photo-content">
              <div class="form-group">
                <label class="form-label">Title <span class="optional-text">(Optional)</span></label>
                <input type="text" class="form-input" 
                       value="${photo.title || ''}" 
                       data-action="input->bulk-upload#updatePhotoTitle" 
                       data-photo-id="${photo.id}"
                       placeholder="Enter title...">
              </div>
              <div class="form-group">
                <label class="form-label">Description <span class="optional-text">(Optional)</span></label>
                <textarea class="form-input" rows="2" 
                          data-action="input->bulk-upload#updatePhotoDescription" 
                          data-photo-id="${photo.id}"
                          placeholder="Enter description...">${photo.description}</textarea>
              </div>
              <div class="file-info">
                <div><strong>File:</strong> ${this.truncateFilename(photo.filename, 30)}</div>
                <div><strong>Size:</strong> ${this.formatFileSize(photo.size)}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    `;
    
    this.stagedPhotosGridTarget.appendChild(photoElement);
  }
  
  updatePhotoTitle(event) {
    const photoId = event.target.dataset.photoId;
    const photo = this.stagedPhotos.find(p => p.id === photoId);
    if (photo) {
      photo.title = event.target.value;
    }
  }
  
  updatePhotoDescription(event) {
    const photoId = event.target.dataset.photoId;
    const photo = this.stagedPhotos.find(p => p.id === photoId);
    if (photo) {
      photo.description = event.target.value;
    }
  }
  
  removePhoto(event) {
    const photoId = event.target.dataset.photoId;
    const photo = this.stagedPhotos.find(p => p.id === photoId);
    const photoName = photo ? photo.filename : 'this photo';
    
    this.showConfirmation(
      'Remove Photo',
      `Remove "${photoName}" from selection?`,
      'Remove',
      () => {
        // Remove from staged photos array
        this.stagedPhotos = this.stagedPhotos.filter(p => p.id !== photoId);
        
        // Remove from DOM
        const photoElement = this.stagedPhotosGridTarget.querySelector(`[data-photo-id="${photoId}"]`);
        if (photoElement) {
          photoElement.remove();
        }
        
        this.updateUI();
      },
      'btn-danger'
    );
  }
  
  
  clearAllStaged() {
    this.showConfirmation(
      'Clear Selected Photos',
      'Remove all selected photos? This cannot be undone.',
      'Clear All',
      () => {
        this.stagedPhotos = [];
        this.stagedPhotosGridTarget.innerHTML = '';
        this.updateUI();
      },
      'btn-danger'
    );
  }
  
  // Confirmation modal methods
  showConfirmation(title, message, buttonText, confirmAction, buttonStyle = 'btn-primary') {
    this.confirmTitleTarget.textContent = title;
    this.confirmMessageTarget.textContent = message;
    this.confirmButtonTarget.textContent = buttonText;
    this.pendingConfirmAction = confirmAction;
    
    // Reset button classes and apply new style
    this.confirmButtonTarget.className = `btn ${buttonStyle}`;
    
    this.confirmModalTarget.style.display = 'block';
    this.confirmModalTarget.classList.add('show');
  }
  
  cancelConfirm() {
    this.confirmModalTarget.style.display = 'none';
    this.confirmModalTarget.classList.remove('show');
    this.pendingConfirmAction = null;
  }
  
  acceptConfirm() {
    this.confirmModalTarget.style.display = 'none';
    this.confirmModalTarget.classList.remove('show');
    
    if (this.pendingConfirmAction) {
      this.pendingConfirmAction();
      this.pendingConfirmAction = null;
    }
  }
  
  async startBulkUpload() {
    if (this.stagedPhotos.length === 0) {
      alert('No photos to upload. Please select some photos first.');
      return;
    }
    
    this.showConfirmation(
      'Upload Photos',
      `Upload ${this.stagedPhotos.length} photo${this.stagedPhotos.length === 1 ? '' : 's'}?`,
      'Upload',
      () => this.performBulkUpload(),
      'btn-success'
    );
  }
  
  async performBulkUpload() {
    
    this.uploadModal.show();
    
    const albumId = this.albumSelectTarget.value;
    let uploadedCount = 0;
    let failedUploads = [];
    
    this.totalUploadCountTarget.textContent = this.stagedPhotos.length;
    this.uploadedCountTarget.textContent = '0';
    
    // Upload photos one by one
    for (let i = 0; i < this.stagedPhotos.length; i++) {
      const photo = this.stagedPhotos[i];
      
      try {
        // Update UI
        this.currentFileNameTarget.textContent = photo.filename;
        const progress = ((i + 1) / this.stagedPhotos.length) * 100;
        this.updateProgress(progress);
        
        // Upload individual photo
        await this.uploadSinglePhoto(photo, albumId);
        
        uploadedCount++;
        this.uploadedCountTarget.textContent = uploadedCount;
        photo.uploadStatus = 'uploaded';
        
      } catch (error) {
        console.error('Upload failed for', photo.filename, error);
        failedUploads.push(`${photo.filename}: ${error.message}`);
        photo.uploadStatus = 'failed';
      }
    }
    
    // Show completion or errors
    if (failedUploads.length > 0) {
      this.showUploadErrors(failedUploads);
    }
    
    // Complete the upload process
    setTimeout(() => {
      this.uploadModal.hide();
      if (uploadedCount > 0) {
        // Clear staged photos that were successfully uploaded
        this.stagedPhotos = this.stagedPhotos.filter(p => p.uploadStatus !== 'uploaded');
        this.rebuildStagingArea();
        this.updateUI();
        
        if (this.stagedPhotos.length === 0) {
          alert(`Successfully uploaded ${uploadedCount} photos!`);
          window.location.href = '/photos'; // Redirect to photos page
        } else {
          alert(`Uploaded ${uploadedCount} photos. ${failedUploads.length} failed.`);
        }
      }
    }, 1000);
  }
  
  async uploadSinglePhoto(photo, albumId) {
    const formData = new FormData();
    formData.append('photo[image]', photo.file);
    formData.append('photo[title]', photo.title || '');
    formData.append('photo[description]', photo.description || '');
    
    // Add to album if specified
    if (albumId) {
      formData.append('photo[album_id]', albumId);
    }
    
    const response = await fetch('/photos', {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      }
    });
    
    if (!response.ok) {
      const responseText = await response.text();
      
      let errorMessage;
      try {
        const errorData = JSON.parse(responseText);
        errorMessage = errorData.errors ? errorData.errors.join(', ') : 'Upload failed';
      } catch {
        errorMessage = `HTTP ${response.status}: ${response.statusText}`;
      }
      throw new Error(errorMessage);
    }
    
    const result = await response.json();
    return result;
  }
  
  showUploadErrors(errors) {
    this.errorsListTarget.innerHTML = '';
    errors.forEach(error => {
      const li = document.createElement('li');
      li.textContent = error;
      this.errorsListTarget.appendChild(li);
    });
    this.uploadErrorsTarget.style.display = 'block';
  }
  
  rebuildStagingArea() {
    this.stagedPhotosGridTarget.innerHTML = '';
    this.stagedPhotos.forEach(photo => {
      if (photo.previewUrl) {
        this.renderStagedPhoto(photo);
      }
    });
  }
  
  updateUI() {
    const count = this.stagedPhotos.length;
    const totalSize = this.stagedPhotos.reduce((sum, photo) => sum + photo.size, 0);
    
    // Update counts
    this.stagedCountTarget.textContent = count;
    this.stagedCountBadgeTarget.textContent = count;
    this.uploadCountTarget.textContent = count;
    this.totalSizeTarget.textContent = this.formatFileSize(totalSize);
    
    // Show/hide elements based on staged photos
    if (count > 0) {
      this.stagingSummaryTarget.style.display = 'block';
      this.stagingBadgeTarget.style.display = 'inline-block';
      this.emptyStateTarget.style.display = 'none';
      this.stagingContainerTarget.style.display = 'block';
      this.uploadButtonTarget.disabled = false;
      
      // Enable bulk action buttons
      this.bulkActionsBtnTargets.forEach(btn => btn.disabled = false);
    } else {
      this.stagingSummaryTarget.style.display = 'none';
      this.stagingBadgeTarget.style.display = 'none';
      this.emptyStateTarget.style.display = 'block';
      this.stagingContainerTarget.style.display = 'none';
      this.uploadButtonTarget.disabled = true;
      
      // Disable bulk action buttons
      this.bulkActionsBtnTargets.forEach(btn => btn.disabled = true);
    }
  }
  
  updateProgress(percent) {
    this.progressBarTarget.style.width = `${percent}%`;
    this.progressTextTarget.textContent = `${Math.round(percent)}%`;
  }
  
  extractTitleFromFilename(filename) {
    // Remove extension and replace underscores/dashes with spaces
    const nameWithoutExt = filename.replace(/\.[^/.]+$/, '');
    return nameWithoutExt
      .replace(/[_-]/g, ' ')
      .replace(/\b\w/g, l => l.toUpperCase())
      .trim();
  }
  
  truncateFilename(filename, maxLength) {
    if (filename.length <= maxLength) return filename;
    const ext = filename.split('.').pop();
    const name = filename.slice(0, filename.lastIndexOf('.'));
    const truncated = name.slice(0, maxLength - ext.length - 4) + '...';
    return truncated + '.' + ext;
  }
  
  isValidFile(file) {
    if (!this.validTypes.includes(file.type)) {
      return false;
    }
    if (file.size > this.maxFileSize) {
      return false;
    }
    return true;
  }
  
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
  }
}