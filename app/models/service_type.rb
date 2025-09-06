class ServiceType < ApplicationRecord
  # Relationships
  belongs_to :vertical
  has_many :appointments, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :min_staff_ratio, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :requiring_background_check, -> { where(requires_background_check: true) }
  scope :for_vertical, ->(vertical_slug) { joins(:vertical).where(verticals: { slug: vertical_slug }) }

  # Delegations
  delegate :cleaning?, :elderly_care?, :requires_compliance_tracking?, to: :vertical

  # Instance methods
  def display_name
    "#{name} (#{duration_in_hours})"
  end

  def duration_in_hours
    hours = duration_minutes / 60.0
    if hours == hours.to_i
      "#{hours.to_i}h"
    else
      "#{hours}h"
    end
  end

  def estimated_cost(hourly_rate = 50.0)
    (duration_minutes / 60.0 * hourly_rate).round(2)
  end

  def requires_multiple_staff?
    min_staff_ratio.present? && min_staff_ratio > 1
  end

  def compliance_requirements
    requirements = []

    requirements << "Background check required" if requires_background_check?
    requirements << "Minimum #{min_staff_ratio} staff members" if requires_multiple_staff?
    requirements << "Compliance tracking enabled" if requires_compliance_tracking?

    requirements
  end

  # Class methods for creating default service types
  def self.create_defaults_for_vertical(vertical)
    case vertical.slug
    when /cleaning/
      create_cleaning_defaults(vertical)
    when /elderly_care/
      create_elderly_care_defaults(vertical)
    when /tutoring/
      create_tutoring_defaults(vertical)
    end
  end

  private

  def self.create_cleaning_defaults(vertical)
    [
      { name: "Basic House Cleaning", duration_minutes: 120, requires_background_check: false },
      { name: "Deep Cleaning", duration_minutes: 240, requires_background_check: false },
      { name: "Move-in/Move-out Cleaning", duration_minutes: 180, requires_background_check: false },
      { name: "Post-Construction Cleanup", duration_minutes: 300, requires_background_check: true }
    ].each do |attrs|
      vertical.service_types.find_or_create_by(name: attrs[:name]) do |service_type|
        service_type.assign_attributes(attrs)
      end
    end
  end

  def self.create_elderly_care_defaults(vertical)
    [
      {
        name: "Companion Care",
        duration_minutes: 240,
        requires_background_check: true,
        min_staff_ratio: 1.0
      },
      {
        name: "Personal Care Assistance",
        duration_minutes: 120,
        requires_background_check: true,
        min_staff_ratio: 1.0
      },
      {
        name: "24-Hour Care",
        duration_minutes: 1440,
        requires_background_check: true,
        min_staff_ratio: 2.0
      },
      {
        name: "Medical Appointment Transport",
        duration_minutes: 180,
        requires_background_check: true,
        min_staff_ratio: 1.0
      }
    ].each do |attrs|
      vertical.service_types.find_or_create_by(name: attrs[:name]) do |service_type|
        service_type.assign_attributes(attrs)
      end
    end
  end

  def self.create_tutoring_defaults(vertical)
    [
      { name: "Elementary Tutoring", duration_minutes: 60, requires_background_check: true },
      { name: "High School Math", duration_minutes: 90, requires_background_check: true },
      { name: "Test Prep (SAT/ACT)", duration_minutes: 120, requires_background_check: true },
      { name: "College Application Help", duration_minutes: 90, requires_background_check: true }
    ].each do |attrs|
      vertical.service_types.find_or_create_by(name: attrs[:name]) do |service_type|
        service_type.assign_attributes(attrs)
      end
    end
  end
end
