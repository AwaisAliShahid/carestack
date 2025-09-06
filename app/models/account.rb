class Account < ApplicationRecord
  # Relationships
  belongs_to :vertical
  has_many :customers, dependent: :destroy
  has_many :staff, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :service_types, through: :vertical

  # Validations
  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true

  # Delegations to vertical for cleaner code
  delegate :display_name, to: :vertical, prefix: true
  delegate :requires_compliance_tracking?, to: :vertical
  delegate :requires_background_checks?, to: :vertical
  delegate :cleaning?, to: :vertical
  delegate :elderly_care?, to: :vertical

  # Scopes
  scope :for_vertical, ->(vertical_slug) { joins(:vertical).where(verticals: { slug: vertical_slug }) }
  scope :cleaning_services, -> { for_vertical("cleaning") }
  scope :elderly_care_services, -> { for_vertical("elderly_care") }

  # Instance methods
  def display_name_with_vertical
    "#{name} (#{vertical_display_name})"
  end

  def total_customers
    customers.count
  end

  def total_staff
    staff.count
  end

  def active_appointments
    appointments.where(status: [ "scheduled", "in_progress" ])
  end

  def completed_appointments_this_month
    appointments.where(
      status: "completed",
      scheduled_at: 1.month.ago.beginning_of_month..Time.current
    )
  end

  # Vertical-specific business rules
  def can_schedule_appointment?(service_type, staff_count)
    return false unless service_type.vertical == vertical

    if requires_background_checks?
      return false unless all_staff_background_checked?
    end

    if elderly_care? && service_type.min_staff_ratio.present?
      return staff_count >= service_type.min_staff_ratio
    end

    true
  end

  def compliance_status
    return :not_required unless requires_compliance_tracking?

    if elderly_care?
      {
        background_checks: staff.where(background_check_passed: true).count,
        total_staff: staff.count,
        compliance_rate: calculate_compliance_rate
      }
    end
  end

  private

  def all_staff_background_checked?
    staff.where(background_check_passed: false).count == 0
  end

  def calculate_compliance_rate
    return 0.0 if staff.count == 0

    (staff.where(background_check_passed: true).count.to_f / staff.count * 100).round(2)
  end
end
