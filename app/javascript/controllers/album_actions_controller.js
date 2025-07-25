import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["confirmModal", "confirmMessage"]
  static values = { albumName: String, deleteUrl: String }

  connect() {
    // Store reference to the modal for easy access
    this.modal = {
      show: () => {
        this.confirmModalTarget.style.display = 'block';
        this.confirmModalTarget.classList.add('show');
      },
      hide: () => {
        this.confirmModalTarget.style.display = 'none';
        this.confirmModalTarget.classList.remove('show');
      }
    };
  }

  confirmDelete(event) {
    // Get album name and delete URL from the button's data attributes
    const albumName = event.target.dataset.albumActionsAlbumNameValue;
    const deleteUrl = event.target.dataset.albumActionsDeleteUrlValue;
    
    // Store for later use
    this.pendingDeleteUrl = deleteUrl;
    
    // Update modal message with album name
    this.confirmMessageTarget.textContent = `Are you sure you want to delete "${albumName}"?`;
    
    // Show the modal
    this.modal.show();
  }

  cancelDelete() {
    this.modal.hide();
    this.pendingDeleteUrl = null;
  }

  confirmDeleteAction() {
    if (this.pendingDeleteUrl) {
      // Create a form and submit it for DELETE request
      const form = document.createElement('form');
      form.method = 'POST';
      form.action = this.pendingDeleteUrl;
      
      // Add Rails authenticity token
      const csrfToken = document.querySelector('meta[name="csrf-token"]').content;
      const csrfInput = document.createElement('input');
      csrfInput.type = 'hidden';
      csrfInput.name = 'authenticity_token';
      csrfInput.value = csrfToken;
      form.appendChild(csrfInput);
      
      // Add method override for DELETE
      const methodInput = document.createElement('input');
      methodInput.type = 'hidden';
      methodInput.name = '_method';
      methodInput.value = 'delete';
      form.appendChild(methodInput);
      
      // Hide modal
      this.modal.hide();
      
      // Submit form
      document.body.appendChild(form);
      form.submit();
    }
  }
}