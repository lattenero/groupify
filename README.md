# Groupify
[![Build Status](https://travis-ci.org/dwbutler/groupify.svg?branch=master)](https://travis-ci.org/dwbutler/groupify) [![Coverage Status](https://coveralls.io/repos/dwbutler/groupify/badge.svg?branch=master&service=github)](https://coveralls.io/github/dwbutler/groupify?branch=master) [![Code Climate](https://codeclimate.com/github/dwbutler/groupify/badges/gpa.svg)](https://codeclimate.com/github/dwbutler/groupify) [![Inline docs](http://inch-ci.org/github/dwbutler/groupify.svg?branch=master)](http://inch-ci.org/github/dwbutler/groupify)

Adds group and membership functionality to Rails models. Defines a polymorphic
relationship between a Group model and any member model. Don't need a Group
model? Use named groups instead to add members to named groups such as
`:admin` or `"Team Rocketpants"`.

## Compatibility

The following ORMs are supported:
 * ActiveRecord 4.2+, 5.x
 * Mongoid 4.x, 5.x, 6.x

The following Rubies are supported:
 * MRI Ruby 2.2, 2.3, 2.4
 * JRuby 9000

The following databases are supported:
 * MySQL
 * PostgreSQL
 * SQLite
 * MongoDB

## Installation

Add this line to your application's Gemfile:

    gem 'groupify'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install groupify

## Setup

### Active Record

Execute:

    $ rails generate groupify:active_record:install

This will generate an initializer, `Group` model, `GroupMembership` model, and migrations.

Modify the models and migrations as needed, then run the migration:

    $ rake db:migrate

Set up your member models:

```ruby
class User < ActiveRecord::Base
  groupify :group_member
  groupify :named_group_member
end

class Assignment < ActiveRecord::Base
  groupify :group_member
end
```

### Mongoid

Execute:

    $ rails generate groupify:mongoid:install

Set up your member models:

```ruby
class User
  include Mongoid::Document

  groupify :group_member
  groupify :named_group_member
end
```

## Test Suite

Run the RSpec test suite by installing the `appraisal` gem and dependencies:

    $ gem install appraisal
    $ appraisal install

And then running tests using `appraisal`:

    $ appraisal rake

## Advanced Configuration

### Groupify Model Names

The default classes for groups, group members and group memberships are configurable.
The default association name for groups and members is also configurable.
Add the following configuration in `config/initializers/groupify.rb` to change the model names for all classes:

```ruby
Groupify.configure do |config|
  config.group_class_name = 'MyCustomGroup'
  config.member_class_name = 'MyCustomMember'

  # Default to `false` so default associations are not automatically created
  config.default_groups_association_name = :groups
  config.default_members_association_name = :members

  # ActiveRecord only
  config.group_membership_class_name = 'MyCustomGroupMembership'
end
```

#### Backwards-compatible Configuration Defaults

The new default configuration does *not* create default associations or make assumptions about your
group and group member class names. If you would like to retain the *legacy* defaults, you can
utilize the `configure_legacy_defaults!` convenience method.

```ruby
Groupify.configure do |config|
  config.configure_legacy_defaults!

  # These are the legacy defaults configured for you:
  # config.group_class_name  = 'Group'
  # config.member_class_name = 'User'
  #
  # config.groups_association_name  = :groups
  # config.members_association_name = :members
end
```

### Groups: Configuring Group Members

Your group class can be configured to create associations for each expected member type.
For example, let's say that your group class will have users and assignments as members.
The following configuration adds `users` and `assignments` associations on the group model:

```ruby
class Group < ActiveRecord::Base
  groupify :group, members: [:users, :assignments], default_members: :users
end
```

In addition to your configuration, Groupify will create a default `members` association.
The default association name can be customized with the `Groupify.default_members_association_name`
setting. If the association name is set to `false`, no default association is created.

The `default_members` option specified in the example above is used to infer the model class when accessing the
default members association (e.g. `members`). Based on the example, `group.members` would return the
users who are members of this group. Note: if `Groupify.default_members_association_name` is set to `false`
then the name specified for `default_members` will be used as the default members association name for this class
(e.g. `group.users` in this case). If that were the case, you would not need to specify `members: [:users]` because
it would be overwritten with a new default association.

If you are using single table inheritance (STI), child classes inherit the member associations
of the parent. If your child class needs to add more members, use the `has_members` method. You can specify
the same options that `has_many through` accepts to customize the association as you please. Note: when using inheritance,
it is recommended to specify the `source_type` option with the base class when you run into circular dependency
issues with your groups and members.

Example:

```ruby
class Organization < Group
  has_members :offices, :equipment
end

class InternationalOrganization < Organization
  has_member :offices, class_name: 'CustomOfficeClass'
  has_member :equipment, class_name: 'CustomEquipmentClass'

  # mitigate issues with inheritance and circular dependencies with groups and members
  has_member :specific_equipment, class_name: 'SpecificEquipment', source_type: 'CustomEquipmentClass'
end
```

Mongoid works the same way by creating Mongoid relations.

With polymorphic groups, the `default_members` option specifies the association
on the group to which members should be added. When specifying individual `has_member`
options, `default_members: true` indicates the association is the one to add new
members to. (If the `default_members` is not specified and the `members` association
does not exist, adding users to subclasses of a group can cause a
`ActiveRecord::AssociationTypeMismatch` exception.)

Example:

```ruby
class GroupBase < ActiveRecord::Base
  self.table_name = "groups"
  self.abstract_class = true
end

class Organization < GroupBase
  acts_as_group
  has_member :users, class_name: 'CustomUserClass', default_members: true
end

org = Organization.create!
user = CustomUserClass.create!

# adds the user to the `ord.users` association
org.add user, as: 'admin'
```

### Group Members: Configuring Groups

Your member class can be configured to create associations for each expected group type.
For example, let's say that your member class will have multiple types of organizations as groups.
The following configuration adds `organizations` and `international_organizations` associations
on the member model:

```ruby
class Group < ActiveRecord::Base
  groupify :group, members: [:users, :assignments], default_members: :users
end

class Organization < Group
  has_members :offices, :equipment
end

class InternationalOrganization < Organization
end

class Member < ActiveRecord::Base
  groupify :group_member, groups: [:groups, :organizations, :international_organizations], default_groups: :groups
end
```

In addition to your configuration, Groupify will create a default `groups` association.
The default association name can be customized with the `Groupify.default_groups_association_name`
setting.

The `default_groups` option specified in the example above sets the model type when accessing the
default groups association (e.g. `groups`). Based on the example, `member.groups` would return the
groups the member has a membership to. Note: if `Groupify.default_groups_association_name` is set to `false`
then the `default_groups` name will be used as the default members association name for this class
(e.g. `member.groups` in this case).

Note: the `group_class_name` option can be specified as the default group class for backwards-compatibility. However,
unlike the `default_groups` option, a default association will not be created if `Groupify.default_groups_association_name`
is set to `false`.

```ruby
class Member < ActiveRecord::Base
  groupify :group_member, group_class_name: 'MyOtherCustomGroup'
end
```

If you are using single table inheritance (STI), child classes inherit the group associations
of the parent. If your child class needs to add more members, use the `has_groups` method. You can specify
the same options that `has_many through` accepts to customize the association as you please. Note: when using inheritance,
it is recommended to specify the `source_type` option with the base class when you run into circular dependency
issues with your groups and members.

Example:

```ruby
class Group < ActiveRecord::Base
  groupify :group, members: [:users, :assignments], default_members: :users
end

class Organization < Group
  has_members :offices, :equipment
end

class InternationalOrganization < Organization
end

class Member < ActiveRecord::Base
  groupify :group_member

  has_group :owned_organizations, class_name: 'Organization'
end
```

### Implementing Group and Group Member on a Single Model (Active Record only)

When a model is designated both as a group and a group member, some things can become ambiguous internally
to Groupify. Usually the context can be inferred. However, when it can't, Groupify assumes that your model
is a member.

For example, if a `Group` can be a member and a group, the following will return groups:

```ruby
class Group < ActiveRecord::Base
  groupify :group
  groupify :group_member
end

member = Group.create!
group  = Group.create!

group.add member, as: :owner

# This will return members who are in groups with the given membership type
Group.as(:owner) # [member]
```

### Polymorphic Groups and Members (Active Record Only)

When you configure multiple models as group or member, you may need to retrieve all groups or members,
particularly if they are not single-table inheritance models. When your models are distributed across
multiple tables, Groupify provides the ability to access all groups or users with the `group.polymorphic_members`
and `member.polymorphic_groups` helper methods. This returns an `Enumerable` collection of groups or members.

Note: this collection effectively retrieves the group memberships and includes the `group_membership.group` or
`group_membership.member` to minimize N+1 queries, then returns only the groups or members from the group memberships
results.

You can filter on membership type:

```ruby
# member example
user.polymorphic_groups.as(:manager)

# group example
group.polymorphic_members.as(:manager)
```

If you want to treat the collection like a scope, you can pass in a block which modifies the
criteria for retrieving the group memberships.

```ruby
# member example
user.polymorphic_groups{where(group_type: 'CustomGroup')}

# group example
group.polymorphic_members{where(member_type: 'CustomMember')}
```

If you want to treat the collection like an association, you can add groups to the collection and
group memberships will be created.

```ruby
# member example
group = Group.new
user.polymorphic_groups << group
user.in_group?(group) # true
# equivalent to:
user.groups << group
user.in_group?(group) # true

# group example
user = User.new
group.polymorphic_members << user
user.in_group?(group) # true
# equivalent to:
group.members << user
user.in_group?(group) # true
```

See _Usage_ below for additional functionality, such as how to specify membership type

## Usage

### Create groups and add members

```ruby
# NOTE: ActiveRecord groups and members must be persisted before creating memberships.
group = Group.create!
user = User.create!

user.groups << group
# or
group.add user

user.in_group?(group)
# => true

# Add multiple members at once
group.add(user, widget, task)
```

### Remove from groups

```ruby
users.groups.destroy(group)          # Destroys this user's group membership for this group
group.users.delete(user)             # Deletes this group's group membership for this user
```

### Named groups

```ruby
user.named_groups << :admin
user.in_named_group?(:admin)        # => true
user.named_groups.destroy(:admin)
```

### Check if two members share any of the same groups:

```ruby
user1.shares_any_group?(user2)          # Returns true if user1 and user2 are in any of the same groups
user2.shares_any_named_group?(user1)    # Also works for named groups
```

### Query for groups & members:

```ruby
User.in_group(group)                # Find all users in this group
User.in_named_group(:admin)         # Find all users in this named group
Group.with_member(user)             # Find all groups with this user

User.shares_any_group(user)         # Find all users that share any groups with this user
User.shares_any_named_group(user)   # Find all users that share any named groups with this user
```

### Check if member belongs to any/all groups

```ruby
User.in_any_group(group1, group2)               # Find users that belong to any of these groups
User.in_all_groups(group1, group2)              # Find users that belong to all of these groups
Widget.in_only_groups(group2, group3)           # Find widgets that belong to only these groups

widget.in_any_named_group?(:foo, :bar)          # Check if widget belongs to any of these named groups
user.in_all_named_groups?(:manager, :poster)    # Check if user belongs to all of these named groups
user.in_only_named_groups?(:employee, :worker)  # Check if user belongs to only these named groups
```

### Merge one group into another:

```ruby
# Moves the members of source into destination, and destroys source
destination_group.merge!(source_group)
```

## Membership Types

Membership types allow a member to belong to a group in a more specific way. For example,
you can add a user to a group with membership type of "manager" to specify that this
user has the "manager role" on that group.

This can be used to implement role-based authorization combined with group authorization,
which could be used to mass-assign roles to groups of resources.

It could also be used to add users and resources to the same "sub-group" or "project"
within a larger group (say, an organization).

```ruby
# Add user to group as a specific membership type
group.add(user, as: 'manager')

# Works with named groups too
user.named_groups.add 'Company', as: 'manager'

# Query for the groups that a user belongs to with a certain role
user.groups.as(:manager)
user.named_groups.as('manager')
Group.with_member(user).as('manager')

# Remove a member's membership type from a group
group.users.delete(user, as: 'manager')         # Deletes this group's 'manager' group membership for this user
user.groups.destroy(group, as: 'employee')      # Destroys this user's 'employee' group membership for this group
user.groups.destroy(group)                      # Destroys any membership types this user had in this group

# Find all members that have a certain membership type in a group
User.in_group(group).as(:manager)

# Find all members of a certain membership type regardless of group
User.as(:manager)    # Find users that are managers, we don't care what group

# Check if a member belongs to any/all groups with a certain membership type
user.in_all_groups?(group1, group2, as: 'manager')

# Find all members that share the same group with the same membership type
Widget.shares_any_group(user).as("Moon Launch Project")

# Check is one member belongs to the same group as another member with a certain membership type
user.shares_any_group?(widget, as: 'employee')
```

Note that adding a member to a group with a specific membership type will automatically
add them to that group without a specific membership type. This way you can still query
`groups` and find the member in that group. If you then remove that specific membership
type, they still remain in the group without a specific membership type.

Removing a member from a group will bulk remove any specific membership types as well.

```
group.add(manager, as: 'manager')
manager.groups.include?(group)              # => true

manager.groups.delete(group, as: 'manager')
manager.groups.include?(group)              # => true

group.add(employee, as: 'employee')
employee.groups.delete(group)
employee.in_group?(group)                   # => false
employee.in_group?(group, as: 'employee')   # => false
```

## Using for Authorization
Groupify was originally created to help implement user authorization, although it can be used
generically for much more than that. Here are some examples of how to do it.

### With CanCan

```ruby
class Ability
  include CanCan::Ability

  def initialize(user)
    # Implements group-based authorization
    # Users can only manage assignment which belong to the same group.
    can [:manage], Assignment, Assignment.shares_any_group(user) do |assignment|
      assignment.shares_any_group?(user)
    end
  end
end
```

### With Authority

```ruby
# Whatever class represents a logged-in user in your app
class User
  groupify :named_group_member
  include Authority::UserAbilities
end

class Widget
  groupify :named_group_member
  include Authority::Abilities
end

class WidgetAuthorizer  < ApplicationAuthorizer
  # Implements group-based authorization using named groups.
  # Users can only see widgets which belong to the same named group.
  def readable_by?(user)
    user.shares_any_named_group?(resource)
  end

  # Implements combined role-based and group-based authorization.
  # Widgets can only be updated by users that are employees of the same named group.
  def updateable_by?(user)
    user.shares_any_named_group?(resource, as: :employee)
  end

  # Widgets can only be deleted by users that are managers of the same named group.
  def deletable_by?(user)
    user.shares_any_named_group?(resource, as: :manager)
  end
end

user = User.create!
user.named_groups.add(:team1, as: :employee)

widget = Widget.create!
widget.named_groups << :team1

widget.readable_by?(user) # => true
user.can_update?(widget)  # => true
user.can_delete?(widget)  # => false
```

### With Pundit

```ruby
class PostPolicy < Struct.new(:user, :post)
  # User can only update a published post if they are admin of the same group.
  def update?
    user.shares_any_group?(post, as: :admin) || !post.published?
  end

  class Scope < Struct.new(:user, :scope)
    def resolve
      if user.admin?
        # An admin can see all the posts in the group(s) they are admin for
        scope.shares_any_group(user).as(:admin)
      else
        # Normal users can only see published posts in the same group(s).
        scope.shares_any_group(user).where(published: true)
      end
    end
  end
end
```

## Backwards-Incompatible Releases

### 0.9+ - Dropped support for Rails 3.2 and Ruby 1.9 - 2.1

Groupify 0.9 added support for Rails 5.1, and dropped support for EOL'ed versions of Ruby,
Rails, ActiveRecord, and Mongoid.

ActiveRecord 5.1 no longer supports passing arguments to collection
associations. Because of this, the undocumented syntax `groups.as(:membership_type)`
is no longer supported.

### 0.8+ - Name Change for `group_memberships` Associations (ActiveRecord only)

Groupify 0.8 changed the ActiveRecord adapter to support configuring the same
model as both a group and a group member. To accomplish this, the internal `group_memberships`
association was renamed to be different for groups and members. If you were
using it, please be aware that you will need to change your code. This
association is considered to be an internal implementation details and not part
of the public API, so please don't rely on it if you can avoid it.

### 0.7+ - Polymorphic Groups (ActiveRecord only)

Groupify < 0.7 required a single `Group` model used for all group memberships.
Groupify 0.7+ supports using multiple models as groups by implementing polymorphic associations.
Upgrading requires adding a new `group_type` column to the `group_memberships` table and
populating that column with the class name of the group. Create the migration by executing:

    $ rails generate groupify:active_record:upgrade

And then run the migration:

    $ rake db:migrate

Please note that this migration may block writes in MySQL if your `group_memberships`
table is large.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Contributors

See a list of contributors [here](https://github.com/dwbutler/groupify/graphs/contributors).
