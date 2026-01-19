# frozen_string_literal: true

module Mutations
  class CreateAppointment < BaseMutation
    description "Create a new appointment with vertical-specific business rules"

    # Direct arguments (simpler approach)
    argument :account_id, ID, required: true
    argument :customer_id, ID, required: true
    argument :service_type_id, ID, required: true
    argument :staff_id, ID, required: true
    argument :scheduled_at, GraphQL::Types::ISO8601DateTime, required: true
    argument :notes, String, required: false

    # Return type
    field :appointment, Types::AppointmentType, null: true
    field :errors, [ String ], null: false

    def resolve(account_id:, customer_id:, service_type_id:, staff_id:, scheduled_at:, notes: nil)
      appointment = nil
      errors = []

      begin
        # Authorize access to the account
        account = authorize_account_access!(account_id)
        customer = Customer.find(customer_id)
        service_type = ServiceType.find(service_type_id)
        staff = Staff.find(staff_id)

        # Validate business rules based on vertical
        validation_errors = validate_appointment_rules(account, service_type, staff)

        if validation_errors.any?
          return {
            appointment: nil,
            errors: validation_errors
          }
        end

        # Create the appointment
        appointment = Appointment.create!(
          account: account,
          customer: customer,
          service_type: service_type,
          staff: staff,
          scheduled_at: scheduled_at,
          duration_minutes: service_type.duration_minutes,
          status: "scheduled",
          notes: notes
        )

        {
          appointment: appointment,
          errors: []
        }

      rescue Authorize::AuthenticationError, Authorize::AuthorizationError
        raise
      rescue ActiveRecord::RecordNotFound => e
        {
          appointment: nil,
          errors: [ "Record not found: #{e.message}" ]
        }
      rescue ActiveRecord::RecordInvalid => e
        {
          appointment: nil,
          errors: e.record.errors.full_messages
        }
      rescue StandardError => e
        {
          appointment: nil,
          errors: [ "An error occurred: #{e.message}" ]
        }
      end
    end

    private

    def validate_appointment_rules(account, service_type, staff)
      errors = []

      # Verify service type belongs to account's vertical
      unless service_type.vertical == account.vertical
        errors << "Service type '#{service_type.name}' is not available for #{account.vertical.display_name} businesses"
      end

      # Verify staff belongs to the account
      unless staff.account == account
        errors << "Staff member does not belong to this account"
      end

      # Vertical-specific validations
      case account.vertical.slug
      when /cleaning/
        errors.concat(validate_cleaning_rules(account, service_type, staff))
      when /elderly_care/
        errors.concat(validate_elderly_care_rules(account, service_type, staff))
      end

      errors
    end

    def validate_cleaning_rules(account, service_type, staff)
      errors = []

      # For post-construction cleanup, require background check
      if service_type.requires_background_check && !staff.background_check_passed
        errors << "Staff member must have passed background check for '#{service_type.name}' service"
      end

      errors
    end

    def validate_elderly_care_rules(account, service_type, staff)
      errors = []

      # Elderly care always requires background checks
      unless staff.background_check_passed
        errors << "All elderly care staff must have passed background checks"
      end

      # Check minimum staff ratio requirements
      if service_type.min_staff_ratio.present? && service_type.min_staff_ratio > 1
        errors << "This service type requires #{service_type.min_staff_ratio} staff members minimum (multi-staff booking not yet implemented)"
      end

      errors
    end
  end
end
