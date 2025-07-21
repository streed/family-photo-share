// Form handling with loading states and client-side validation
document.addEventListener('DOMContentLoaded', function() {
  // Add loading states to form submissions
  document.querySelectorAll('form').forEach(function(form) {
    form.addEventListener('submit', function(e) {
      const submitButton = form.querySelector('input[type="submit"], button[type="submit"]');
      if (submitButton && !submitButton.disabled) {
        showLoadingState(submitButton);
      }
    });
  });

  // Client-side validation for photo uploads
  document.querySelectorAll('input[type="file"][accept*="image"]').forEach(function(input) {
    input.addEventListener('change', function(e) {
      const file = e.target.files[0];
      if (file) {
        // Check file size (10MB limit)
        const maxSize = 10 * 1024 * 1024; // 10MB
        if (file.size > maxSize) {
          showFormError(input.closest('form'), 'File size must be less than 10MB');
          input.value = '';
          return;
        }

        // Check file type
        const allowedTypes = ['image/jpeg', 'image/png', 'image/gif'];
        if (!allowedTypes.includes(file.type)) {
          showFormError(input.closest('form'), 'Please select a valid image file (JPEG, PNG, or GIF)');
          input.value = '';
          return;
        }

        // Show preview if possible
        showImagePreview(input, file);
      }
    });
  });

  // Email validation
  document.querySelectorAll('input[type="email"]').forEach(function(input) {
    input.addEventListener('blur', function() {
      if (input.value && !isValidEmail(input.value)) {
        input.classList.add('is-invalid');
        showFieldError(input, 'Please enter a valid email address');
      } else {
        input.classList.remove('is-invalid');
        hideFieldError(input);
      }
    });
  });

  // Password strength validation
  document.querySelectorAll('input[type="password"][id*="password"]').forEach(function(input) {
    input.addEventListener('input', function() {
      if (input.value.length > 0) {
        const strength = getPasswordStrength(input.value);
        showPasswordStrength(input, strength);
      } else {
        hidePasswordStrength(input);
      }
    });
  });
});

function showImagePreview(input, file) {
  const reader = new FileReader();
  reader.onload = function(e) {
    // Remove existing preview
    const existingPreview = input.parentNode.querySelector('.image-preview');
    if (existingPreview) {
      existingPreview.remove();
    }

    // Create preview
    const preview = document.createElement('div');
    preview.className = 'image-preview mt-2';
    preview.innerHTML = `
      <img src="${e.target.result}" alt="Preview" style="max-width: 200px; max-height: 200px; border-radius: 4px;">
      <p class="small text-muted mt-1">${file.name} (${formatFileSize(file.size)})</p>
    `;
    
    input.parentNode.appendChild(preview);
  };
  reader.readAsDataURL(file);
}

function formatFileSize(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

function showFieldError(field, message) {
  // Remove existing error
  hideFieldError(field);
  
  // Create error element
  const error = document.createElement('div');
  error.className = 'field-error text-danger small mt-1';
  error.textContent = message;
  
  // Insert after field
  field.parentNode.insertBefore(error, field.nextSibling);
}

function hideFieldError(field) {
  const error = field.parentNode.querySelector('.field-error');
  if (error) {
    error.remove();
  }
}

function getPasswordStrength(password) {
  let score = 0;
  if (password.length >= 8) score++;
  if (password.match(/[a-z]/)) score++;
  if (password.match(/[A-Z]/)) score++;
  if (password.match(/[0-9]/)) score++;
  if (password.match(/[^a-zA-Z0-9]/)) score++;
  
  return {
    score: score,
    text: ['Very Weak', 'Weak', 'Fair', 'Good', 'Strong'][score] || 'Very Weak'
  };
}

function showPasswordStrength(input, strength) {
  // Remove existing strength indicator
  hidePasswordStrength(input);
  
  // Create strength indicator
  const indicator = document.createElement('div');
  indicator.className = 'password-strength mt-1';
  
  const colors = ['#dc3545', '#fd7e14', '#ffc107', '#28a745', '#007bff'];
  const color = colors[strength.score] || colors[0];
  
  indicator.innerHTML = `
    <div class="strength-bar">
      <div class="strength-fill" style="width: ${(strength.score / 5) * 100}%; background-color: ${color};"></div>
    </div>
    <small class="strength-text" style="color: ${color};">${strength.text}</small>
  `;
  
  input.parentNode.appendChild(indicator);
}

function hidePasswordStrength(input) {
  const indicator = input.parentNode.querySelector('.password-strength');
  if (indicator) {
    indicator.remove();
  }
}