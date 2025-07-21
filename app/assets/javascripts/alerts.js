// Alert handling functionality
document.addEventListener('DOMContentLoaded', function() {
  // Handle alert close buttons
  document.querySelectorAll('.alert-close').forEach(function(button) {
    button.addEventListener('click', function() {
      const alert = this.closest('.alert');
      if (alert) {
        alert.style.opacity = '0';
        setTimeout(function() {
          alert.remove();
        }, 300);
      }
    });
  });

  // Auto-dismiss alerts
  document.querySelectorAll('.alert[data-auto-dismiss]').forEach(function(alert) {
    const dismissTime = parseInt(alert.dataset.autoDismiss, 10);
    if (dismissTime > 0) {
      setTimeout(function() {
        if (alert.parentNode) {
          alert.style.opacity = '0';
          setTimeout(function() {
            if (alert.parentNode) {
              alert.remove();
            }
          }, 300);
        }
      }, dismissTime);
    }
  });
});

// Form validation helpers
function showFormError(form, message) {
  // Remove existing error alerts
  form.querySelectorAll('.alert-danger').forEach(function(alert) {
    alert.remove();
  });

  // Create new error alert
  const errorDiv = document.createElement('div');
  errorDiv.className = 'alert alert-danger alert-dismissible';
  errorDiv.innerHTML = message + '<button type="button" class="alert-close" data-dismiss="alert">&times;</button>';
  
  // Insert at the top of the form
  form.insertBefore(errorDiv, form.firstChild);
  
  // Add click handler for close button
  errorDiv.querySelector('.alert-close').addEventListener('click', function() {
    errorDiv.style.opacity = '0';
    setTimeout(function() {
      errorDiv.remove();
    }, 300);
  });
}

function showFormSuccess(form, message) {
  // Remove existing success alerts
  form.querySelectorAll('.alert-success').forEach(function(alert) {
    alert.remove();
  });

  // Create new success alert
  const successDiv = document.createElement('div');
  successDiv.className = 'alert alert-success alert-dismissible';
  successDiv.innerHTML = message + '<button type="button" class="alert-close" data-dismiss="alert">&times;</button>';
  
  // Insert at the top of the form
  form.insertBefore(successDiv, form.firstChild);
  
  // Add click handler for close button
  successDiv.querySelector('.alert-close').addEventListener('click', function() {
    successDiv.style.opacity = '0';
    setTimeout(function() {
      successDiv.remove();
    }, 300);
  });

  // Auto-dismiss after 3 seconds
  setTimeout(function() {
    if (successDiv.parentNode) {
      successDiv.style.opacity = '0';
      setTimeout(function() {
        if (successDiv.parentNode) {
          successDiv.remove();
        }
      }, 300);
    }
  }, 3000);
}

// Loading state helpers
function showLoadingState(button) {
  button.disabled = true;
  button.dataset.originalText = button.textContent;
  button.textContent = 'Loading...';
  button.classList.add('btn-loading');
}

function hideLoadingState(button) {
  button.disabled = false;
  button.textContent = button.dataset.originalText || button.textContent;
  button.classList.remove('btn-loading');
}