# Architecture Update: Single Family Per User

## Overview

The family photo sharing application has been updated to enforce a **single family per user** constraint. This architectural change simplifies the user experience and data model while maintaining all core functionality.

## Changes Made

### Database Schema
- Added unique constraint on `user_id` in `family_memberships` table
- Migration `20250719054905_enforce_single_family_per_user.rb` removes duplicate memberships and enforces uniqueness

### Model Updates
1. **User Model** (`app/models/user.rb`)
   - Changed `has_many :family_memberships` to `has_one :family_membership`
   - Changed `has_many :families` to `has_one :family`
   - Updated family-related methods to work with single family
   - Added `can_create_family?` method returning `!has_family?`

2. **FamilyMembership Model** (`app/models/family_membership.rb`)
   - Updated validation from scoped uniqueness to simple uniqueness on `user_id`
   - Added custom validation message: "can only belong to one family"
   - Updated validation logic to prevent users from joining multiple families

3. **Album Model** (`app/models/album.rb`)
   - Updated `accessible_by?` method to use single family relationship
   - Changed from `user&.families&.exists?` to `user&.family == self.user.family`

### Controller Updates
1. **FamiliesController** (`app/controllers/families_controller.rb`)
   - `index` action redirects users with families to their family page
   - `new` and `create` actions check `can_create_family?` permission
   - Updated navigation logic for single family

2. **FamilyInvitationsController** (`app/controllers/family_invitations_controller.rb`)
   - Updated invitation acceptance to check if user already has a family
   - Improved error handling for single family constraint

3. **HomeController** (`app/controllers/home_controller.rb`)
   - Updated dashboard to show single family information

### View Updates
1. **Navigation** (`app/views/layouts/application.html.erb`)
   - Changed from "Join Family" to appropriate single family context
   - Updated navigation logic based on `has_family?` status

2. **Home Dashboard** (`app/views/home/index.html.erb`)
   - Updated family section to show single family status
   - Changed plural "Families" to singular "Family"

3. **Family Views**
   - Updated `families/index.html.erb` to handle single family logic
   - Simplified UI elements that referenced multiple families

### Test Updates
All model and controller tests have been updated to reflect the single family constraint:

1. **User Model Tests** (`spec/models/user_spec.rb`)
   - Added tests for `has_family?`, `can_create_family?`, `family_role`, and `family_admin?` methods
   - Updated association tests to use `has_one` instead of `has_many`

2. **FamilyMembership Tests** (`spec/models/family_membership_spec.rb`)
   - Updated uniqueness validation tests for new constraint
   - Added tests to verify single family enforcement

3. **Album Tests** (`spec/models/album_spec.rb`)
   - Updated `accessible_by?` tests for single family logic
   - Added comprehensive family access control tests

## Benefits of Single Family Constraint

1. **Simplified User Experience**: Users have one family context, reducing confusion
2. **Cleaner Data Model**: Eliminates complex multi-family logic and edge cases
3. **Improved Performance**: Simplified queries and reduced data complexity
4. **Better Privacy Control**: Clear single family boundary for photo sharing
5. **Easier Role Management**: Users have one role in one family context

## Migration Path

The migration automatically handles existing users with multiple families by:
1. Keeping the earliest family membership for each user
2. Removing subsequent family memberships
3. Adding unique constraint to prevent future violations

## API Impact

All existing API endpoints continue to work, but now operate within the single family context:
- Family-related endpoints work with the user's one family
- Photo sharing is scoped to the single family
- Album privacy "family" setting applies to the user's family

## Backwards Compatibility

While the data model has changed, the application interface remains largely the same:
- All existing features continue to function
- URLs and routes remain unchanged  
- User workflow is simplified but familiar

## Future Considerations

This architectural change positions the application for:
- Simplified onboarding flow
- Clearer permission models
- Easier family management features
- More intuitive photo organization

---

*Last updated: 2025-07-19*
*Related migration: `20250719054905_enforce_single_family_per_user.rb`*