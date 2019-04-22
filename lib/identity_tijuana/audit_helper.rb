module AuditHelper
  module ClassMethods
    def audit_method(object_string)
      external_count, local_count = eval('audit_'+object_string.underscore)
      return {
        external: external_count,
        local: local_count,
        diff: local_count - external_count
      }
    end

    def audit_contact_campaign
      return 0,0
    end

    def audit_contact
      return 0,0
    end

    def audit_contact_response
      return 0,0
    end

    def audit_contact_response_key
      return 0,0
    end
  end

  extend ClassMethods
  def self.included(other)
    other.extend(ClassMethods)
  end
end