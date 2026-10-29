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
    this.maxFileSize = 50 * 1024 * 1024; // 50MB — the same ceiling the Photo model enforces
    this.maxConcurrentUploads = 3;
    this.validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];

    // Photos start uploading the moment they are added, so each one tracks its
    // own request: uploadStatus is queued, uploading, uploaded or failed.
    this.stagedPhotos = [];
    this.nextPhotoId = 1;
    this.finishing = false;

    // Photos that already reached the server are only half-saved until Finish.
    this.beforeUnload = (event) => {
      if (this.stagedPhotos.some(p => p.uploadStatus !== 'failed') && !this.finishing) {
        event.preventDefault();
        event.returnValue = '';
      }
    };
    window.addEventListener('beforeunload', this.beforeUnload);

    // The .modal component class owns display; `show` is the only toggle.
    this.uploadModal = {
      show: () => this.uploadModalTarget.classList.add('show'),
      hide: () => this.uploadModalTarget.classList.remove('show')
    };

    this.updateUI();
  }

  disconnect() {
    window.removeEventListener('beforeunload', this.beforeUnload);
  }

  addMultiplePhotos(event) {
    const files = Array.from(event.target.files);
    if (!files.length) {
      return;
    }

    const validFiles = files.filter(file => this.isValidFile(file));
    const skipped = files.length - validFiles.length;

    if (skipped > 0) {
      alert(`${skipped} file${skipped === 1 ? ' was' : 's were'} skipped (invalid format or too large).`);
    }

    validFiles.forEach(file => this.addFileToStaging(file));
    this.multipleFileInputTarget.value = ''; // Clear input
    this.pumpUploads();
  }

  addFileToStaging(file) {
    const stagedPhoto = {
      id: `photo-${this.nextPhotoId++}`,
      file: file,
      filename: file.name,
      size: file.size,
      title: this.extractTitleFromFilename(file.name),
      description: '',
      // An object URL, not a data URL: with no cap on the batch, holding every
      // preview as a base64 string would balloon memory.
      previewUrl: URL.createObjectURL(file),
      uploadStatus: 'queued',
      serverId: null,
      xhr: null,
      removed: false
    };

    this.stagedPhotos.push(stagedPhoto);
    this.renderStagedPhoto(stagedPhoto);
    this.updateUI();
  }

  renderStagedPhoto(photo) {
    const photoElement = document.createElement('div');
    photoElement.className = 'staged-photo-item card';
    photoElement.dataset.photoId = photo.id;

    photoElement.innerHTML = `
      <div class="flex gap-3 p-3">
        <div class="relative shrink-0">
          <img src="${photo.previewUrl}" alt="" class="h-24 w-24 rounded-lg object-cover">
          <button type="button" class="icon-btn icon-btn-danger absolute -right-2 -top-2 h-7 w-7 shadow-[var(--shadow-soft)]"
                  data-action="click->bulk-upload#removePhoto"
                  data-photo-id="${photo.id}"
                  aria-label="Remove this photo">
            &times;
          </button>
        </div>
        <div class="min-w-0 grow">
          <div class="field mb-2">
            <label class="field-label">Title</label>
            <input type="text" class="field-input"
                   data-photo-field="title"
                   data-action="input->bulk-upload#updatePhotoTitle"
                   data-photo-id="${photo.id}"
                   placeholder="Optional">
          </div>
          <div class="field mb-2">
            <label class="field-label">Description</label>
            <textarea class="field-input" rows="2"
                      data-photo-field="description"
                      data-action="input->bulk-upload#updatePhotoDescription"
                      data-photo-id="${photo.id}"
                      placeholder="Optional"></textarea>
          </div>
          <p class="meta truncate"></p>
          <div class="progress-track mt-2">
            <div class="progress-fill bg-primary" data-photo-progress style="width: 0%"></div>
          </div>
          <p class="meta mt-1 flex items-center gap-2" data-photo-status></p>
        </div>
      </div>
    `;

    // Values go in through the DOM so a quote in a title can't break the markup.
    photoElement.querySelector('[data-photo-field="title"]').value = photo.title || '';
    photoElement.querySelector('[data-photo-field="description"]').value = photo.description || '';
    photoElement.querySelector('p.meta').textContent =
      `${this.truncateFilename(photo.filename, 30)} · ${this.formatFileSize(photo.size)}`;

    this.stagedPhotosGridTarget.appendChild(photoElement);
    this.renderPhotoStatus(photo);
  }

  // Updates one tile's progress and status line in place, so typing in its
  // title field is never interrupted by a re-render.
  renderPhotoStatus(photo, percent = null) {
    const element = this.photoElement(photo.id);
    if (!element) return;

    const bar = element.querySelector('[data-photo-progress]');
    const status = element.querySelector('[data-photo-status]');
    const labels = {
      queued: 'Waiting to upload…',
      uploading: 'Uploading…',
      uploaded: 'Uploaded',
      failed: photo.error || 'Upload failed'
    };

    if (percent !== null) {
      bar.style.width = `${percent}%`;
    } else if (photo.uploadStatus === 'uploaded') {
      bar.style.width = '100%';
    } else if (photo.uploadStatus === 'failed' || photo.uploadStatus === 'queued') {
      bar.style.width = '0%';
    }

    status.textContent = labels[photo.uploadStatus];
    if (photo.uploadStatus === 'failed') {
      const retry = document.createElement('button');
      retry.type = 'button';
      retry.className = 'btn btn-ghost btn-sm';
      retry.textContent = 'Retry';
      retry.dataset.action = 'click->bulk-upload#retryPhoto';
      retry.dataset.photoId = photo.id;
      status.appendChild(retry);
    }
  }

  photoElement(photoId) {
    return this.stagedPhotosGridTarget.querySelector(`[data-photo-id="${photoId}"].staged-photo-item`);
  }

  updatePhotoTitle(event) {
    const photo = this.stagedPhotos.find(p => p.id === event.target.dataset.photoId);
    if (photo) {
      photo.title = event.target.value;
    }
  }

  updatePhotoDescription(event) {
    const photo = this.stagedPhotos.find(p => p.id === event.target.dataset.photoId);
    if (photo) {
      photo.description = event.target.value;
    }
  }

  // ---- Background uploads ------------------------------------------------

  pumpUploads() {
    let active = this.stagedPhotos.filter(p => p.uploadStatus === 'uploading').length;

    for (const photo of this.stagedPhotos) {
      if (active >= this.maxConcurrentUploads) break;
      if (photo.uploadStatus !== 'queued') continue;

      active++;
      this.uploadPhoto(photo);
    }
  }

  uploadPhoto(photo) {
    photo.uploadStatus = 'uploading';
    photo.error = null;
    this.renderPhotoStatus(photo, 0);
    this.updateUI();

    const formData = new FormData();
    formData.append('photo[image]', photo.file);
    formData.append('photo[title]', photo.title || '');

    // Plain XHR rather than fetch: it reports upload progress and abort()
    // cancels the transfer, which is what removing an in-flight photo needs.
    const xhr = new XMLHttpRequest();
    photo.xhr = xhr;
    xhr.open('POST', '/photos');
    xhr.setRequestHeader('X-CSRF-Token', document.querySelector('meta[name="csrf-token"]').content);
    xhr.setRequestHeader('Accept', 'application/json');

    xhr.upload.onprogress = (event) => {
      if (event.lengthComputable) {
        this.renderPhotoStatus(photo, (event.loaded / event.total) * 100);
      }
    };
    xhr.onload = () => {
      photo.xhr = null;
      if (xhr.status >= 200 && xhr.status < 300) {
        photo.serverId = JSON.parse(xhr.responseText).id;
        photo.uploadStatus = 'uploaded';
        // Removed after the bytes were already on their way: the abort lost the
        // race, so the photo exists server-side and has to be deleted there.
        if (photo.removed) this.deleteFromServer(photo);
      } else {
        photo.uploadStatus = 'failed';
        photo.error = this.errorFromResponse(xhr);
      }
      this.uploadSettled(photo);
    };
    xhr.onerror = () => {
      photo.xhr = null;
      photo.uploadStatus = 'failed';
      photo.error = 'Network error';
      this.uploadSettled(photo);
    };
    xhr.onabort = () => {
      photo.xhr = null;
    };

    xhr.send(formData);
  }

  uploadSettled(photo) {
    if (!photo.removed) this.renderPhotoStatus(photo);
    this.updateUI();
    this.pumpUploads();
  }

  errorFromResponse(xhr) {
    try {
      const data = JSON.parse(xhr.responseText);
      if (data.errors) return data.errors.join(', ');
    } catch {
      // fall through to the generic message
    }
    return `HTTP ${xhr.status}: ${xhr.statusText}`;
  }

  retryPhoto(event) {
    const photo = this.stagedPhotos.find(p => p.id === event.target.dataset.photoId);
    if (!photo || photo.uploadStatus !== 'failed') return;

    photo.uploadStatus = 'queued';
    this.renderPhotoStatus(photo);
    this.updateUI();
    this.pumpUploads();
  }

  async deleteFromServer(photo) {
    const response = await fetch(`/photos/${photo.serverId}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      }
    });
    return response.ok;
  }

  // ---- Removing photos ---------------------------------------------------

  removePhoto(event) {
    const photoId = event.currentTarget.dataset.photoId;
    const photo = this.stagedPhotos.find(p => p.id === photoId);
    if (!photo) return;

    // Anything not yet on the server can just be dropped. A finished upload is
    // a real photo in the library, so deleting it gets a confirmation.
    if (photo.uploadStatus !== 'uploaded') {
      this.discardPhoto(photo);
      return;
    }

    this.showConfirmation(
      'Remove Photo',
      `"${photo.filename}" is already uploaded. Delete it?`,
      'Delete',
      () => this.discardPhoto(photo),
      'btn-danger'
    );
  }

  async discardPhoto(photo) {
    photo.removed = true;

    if (photo.uploadStatus === 'uploading' && photo.xhr) {
      photo.xhr.abort();
    }

    if (photo.uploadStatus === 'uploaded') {
      const status = this.photoElement(photo.id)?.querySelector('[data-photo-status]');
      if (status) status.textContent = 'Deleting…';

      if (!await this.deleteFromServer(photo)) {
        // Still on the server, so keep it in the list rather than pretend.
        photo.removed = false;
        if (status) status.textContent = "Couldn't delete this photo. Try again.";
        return;
      }
    }

    this.stagedPhotos = this.stagedPhotos.filter(p => p !== photo);
    this.photoElement(photo.id)?.remove();
    URL.revokeObjectURL(photo.previewUrl);
    this.updateUI();
    this.pumpUploads();
  }

  clearAllStaged() {
    const uploaded = this.stagedPhotos.filter(p => p.uploadStatus === 'uploaded').length;
    const message = uploaded > 0
      ? `Remove all selected photos? ${uploaded} already uploaded will be deleted. This cannot be undone.`
      : 'Remove all selected photos? This cannot be undone.';

    this.showConfirmation(
      'Clear Selected Photos',
      message,
      'Clear All',
      () => [...this.stagedPhotos].forEach(photo => this.discardPhoto(photo)),
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

    this.confirmModalTarget.classList.add('show');
  }

  cancelConfirm() {
    this.confirmModalTarget.classList.remove('show');
    this.pendingConfirmAction = null;
  }

  acceptConfirm() {
    this.confirmModalTarget.classList.remove('show');

    if (this.pendingConfirmAction) {
      this.pendingConfirmAction();
      this.pendingConfirmAction = null;
    }
  }

  // ---- Finishing ---------------------------------------------------------

  startBulkUpload() {
    if (this.stagedPhotos.length === 0) {
      alert('No photos to upload. Please select some photos first.');
      return;
    }

    const failed = this.stagedPhotos.filter(p => p.uploadStatus === 'failed').length;
    const count = this.stagedPhotos.length - failed;
    const note = failed > 0 ? ` ${failed} that failed to upload will be left out.` : '';

    this.showConfirmation(
      'Finish Upload',
      `Save ${count} photo${count === 1 ? '' : 's'}?${note}`,
      'Save',
      () => this.finish(),
      'btn-success'
    );
  }

  async finish() {
    this.finishing = true;
    this.uploadModal.show();
    this.currentFileNameTarget.textContent = 'the last few photos';
    this.totalUploadCountTarget.textContent = this.stagedPhotos.filter(p => p.uploadStatus !== 'failed').length;

    // Uploads started when the photos were added; wait for whatever is left.
    await this.waitForUploads();

    const photos = this.stagedPhotos.filter(p => p.uploadStatus === 'uploaded');
    this.uploadedCountTarget.textContent = photos.length;
    this.updateProgress(100);

    try {
      const response = await fetch('/photos/finalize', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          album_id: this.albumSelectTarget.value || null,
          photos: photos.map(p => ({ id: p.serverId, title: p.title, description: p.description }))
        })
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || `HTTP ${response.status}`);
      if (result.failed.length > 0) throw new Error(`${result.failed.length} photos could not be saved`);
    } catch (error) {
      this.finishing = false;
      this.uploadModal.hide();
      alert(`Something went wrong saving your photos: ${error.message}. They're uploaded, so you can try Save again.`);
      return;
    }

    this.uploadModal.hide();
    const failedLeft = this.stagedPhotos.filter(p => p.uploadStatus === 'failed');
    photos.forEach(photo => {
      this.photoElement(photo.id)?.remove();
      URL.revokeObjectURL(photo.previewUrl);
    });
    this.stagedPhotos = failedLeft;
    this.updateUI();

    if (failedLeft.length === 0) {
      // Land where the photos went: the album if one was chosen, else the library.
      const albumId = this.albumSelectTarget.value;
      window.location.href = albumId ? `/albums/${albumId}` : '/photos';
    } else {
      this.finishing = false;
      alert(`Saved ${photos.length} photos. ${failedLeft.length} failed to upload — retry them or remove them.`);
    }
  }

  waitForUploads() {
    const pending = () => this.stagedPhotos.some(p => p.uploadStatus === 'queued' || p.uploadStatus === 'uploading');

    return new Promise(resolve => {
      const check = () => {
        const done = this.stagedPhotos.filter(p => p.uploadStatus === 'uploaded').length;
        this.uploadedCountTarget.textContent = done;
        const total = this.stagedPhotos.filter(p => p.uploadStatus !== 'failed').length;
        this.updateProgress(total ? (done / total) * 100 : 100);

        if (pending()) {
          setTimeout(check, 300);
        } else {
          resolve();
        }
      };
      check();
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
      this.stagingSummaryTarget.hidden = false;
      this.stagingBadgeTarget.hidden = false;
      this.emptyStateTarget.hidden = true;
      this.stagingContainerTarget.hidden = false;
      this.uploadButtonTarget.disabled = false;
      
      // Enable bulk action buttons
      this.bulkActionsBtnTargets.forEach(btn => btn.disabled = false);
    } else {
      this.stagingSummaryTarget.hidden = true;
      this.stagingBadgeTarget.hidden = true;
      this.emptyStateTarget.hidden = false;
      this.stagingContainerTarget.hidden = true;
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