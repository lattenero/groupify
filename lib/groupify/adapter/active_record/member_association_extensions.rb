require 'groupify/adapter/active_record/association_extensions'

module Groupify
  module ActiveRecord
    module MemberAssociationExtensions
      include AssociationExtensions

    protected

      def association_parent_type
        :group
      end

      def find_memberships_for(member, membership_type)
        proxy_association.owner.group_memberships_as_group.where(member_id: member.id, member_type: member.class.base_class.to_s, membership_type: membership_type)
      end

      def find_for_destruction(membership_type, *members)
        proxy_association.owner.group_memberships_as_group.
          where(member_id: members.map(&:id), member_type: proxy_association.reflection.options[:source_type]).
          as(membership_type)
      end
    end
  end
end