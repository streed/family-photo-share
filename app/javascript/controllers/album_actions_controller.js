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
    // currentTarget, not target: clicking the <i> icon inside the button would
    // otherwise read the icon's (empty) dataset.
    const button = event.currentTarget;
    const albumName = button.dataset.albumActionsAlbumNameValue;
    const deleteUrl = button.dataset.albumActionsDeleteUrlValue;

    if (!deleteUrl) return;

    this.pendingDeleteUrl = deleteUrl;

    // Views that don't carry the modal markup (e.g. the albums index) still get
    // a confirmation rather than a dead button.
    if (!this.hasConfirmModalTarget || !this.hasConfirmMessageTarget) {
      if (window.confirm(`Are you sure you want to delete "${albumName}"?`)) {
        this.confirmDeleteAction();
      } else {
        this.pendingDeleteUrl = null;
      }
      return;
    }

    this.confirmMessageTarget.textContent = `Are you sure you want to delete "${albumName}"?`;
    this.modal.show();
  }

  cancelDelete() {
    if (this.hasConfirmModalTarget) this.modal.hide();
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
      if (this.hasConfirmModalTarget) this.modal.hide();

      // Submit form
      document.body.appendChild(form);
      form.submit();
    }
  }
}