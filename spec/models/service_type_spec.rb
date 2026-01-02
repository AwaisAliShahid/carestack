# frozen_string_literal: true

require "rails_helper"

RSpec.describe ServiceType, type: :model do
  describe "validations" do
    subject { build(:service_type) }

    it { is_expected.to be_valid }

    describe "name" do
      it "is required" do
        subject.name = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:name]).to include("can't be blank")
      end
    end

    describe "duration_minutes" do
      it "is required" do
        subject.duration_minutes = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:duration_minutes]).to include("can't be blank")
      end

      it "must be greater than 0" do
        subject.duration_minutes = 0
        expect(subject).not_to be_valid
        expect(subject.errors[:duration_minutes]).to include("must be greater than 0")
      end

      it "accepts positive values" do
        subject.duration_minutes = 60
        expect(subject).to be_valid
      end
    end

    describe "min_staff_ratio" do
      it "allows nil values" do
        subject.min_staff_ratio = nil
        expect(subject).to be_valid
      end

      it "must be greater than 0 when present" do
        subject.min_staff_ratio = 0
        expect(subject).not_to be_valid
        expect(subject.errors[:min_staff_ratio]).to include("must be greater than 0")
      end

      it "accepts positive values" do
        subject.min_staff_ratio = 2.0
        expect(subject).to be_valid
      end
    end
  end

  describe "associations" do
    let(:service_type) { create(:service_type) }

    it "belongs to a vertical" do
      expect(service_type.vertical).to be_a(Vertical)
    end

    it "has many appointments" do
      appointment = create(:appointment, service_type: service_type)
      expect(service_type.appointments).to include(appointment)
    end

    it "destroys appointments when service_type is destroyed" do
      create(:appointment, service_type: service_type)
      expect { service_type.destroy }.to change(Appointment, :count).by(-1)
    end
  end

  describe "scopes" do
    describe ".requiring_background_check" do
      it "returns only service types requiring background check" do
        with_check = create(:service_type, requires_background_check: true)
        create(:service_type, requires_background_check: false)

        expect(ServiceType.requiring_background_check).to eq([ with_check ])
      end
    end

    describe ".for_vertical" do
      it "returns service types for the specified vertical slug" do
        cleaning_vertical = create(:vertical, :cleaning)
        elderly_vertical = create(:vertical, :elderly_care)

        cleaning_service = create(:service_type, vertical: cleaning_vertical)
        create(:service_type, vertical: elderly_vertical)

        expect(ServiceType.for_vertical("cleaning")).to eq([ cleaning_service ])
      end
    end
  end

  describe "delegations" do
    describe "#cleaning?" do
      it "delegates to vertical" do
        service_type = create(:service_type, :basic_cleaning)
        expect(service_type.cleaning?).to be true
      end
    end

    describe "#elderly_care?" do
      it "delegates to vertical" do
        service_type = create(:service_type, :companion_care)
        expect(service_type.elderly_care?).to be true
      end
    end

    describe "#requires_compliance_tracking?" do
      it "delegates to vertical" do
        service_type = create(:service_type, :companion_care)
        expect(service_type.requires_compliance_tracking?).to be true
      end
    end
  end

  describe "instance methods" do
    describe "#display_name" do
      it "returns name with duration in hours" do
        service_type = build(:service_type, name: "Deep Cleaning", duration_minutes: 120)
        expect(service_type.display_name).to eq("Deep Cleaning (2h)")
      end
    end

    describe "#duration_in_hours" do
      it "returns whole hours for even durations" do
        service_type = build(:service_type, duration_minutes: 120)
        expect(service_type.duration_in_hours).to eq("2h")
      end

      it "returns decimal hours for uneven durations" do
        service_type = build(:service_type, duration_minutes: 90)
        expect(service_type.duration_in_hours).to eq("1.5h")
      end

      it "handles 30 minute durations" do
        service_type = build(:service_type, duration_minutes: 30)
        expect(service_type.duration_in_hours).to eq("0.5h")
      end
    end

    describe "#estimated_cost" do
      it "calculates cost with default hourly rate" do
        service_type = build(:service_type, duration_minutes: 120)
        expect(service_type.estimated_cost).to eq(100.0) # 2 hours * $50
      end

      it "calculates cost with custom hourly rate" do
        service_type = build(:service_type, duration_minutes: 60)
        expect(service_type.estimated_cost(75.0)).to eq(75.0)
      end

      it "handles fractional hours" do
        service_type = build(:service_type, duration_minutes: 90)
        expect(service_type.estimated_cost(40.0)).to eq(60.0) # 1.5 hours * $40
      end
    end

    describe "#requires_multiple_staff?" do
      it "returns false when min_staff_ratio is nil" do
        service_type = build(:service_type, min_staff_ratio: nil)
        expect(service_type.requires_multiple_staff?).to be false
      end

      it "returns false when min_staff_ratio is 1" do
        service_type = build(:service_type, min_staff_ratio: 1.0)
        expect(service_type.requires_multiple_staff?).to be false
      end

      it "returns true when min_staff_ratio is greater than 1" do
        service_type = build(:service_type, min_staff_ratio: 2.0)
        expect(service_type.requires_multiple_staff?).to be true
      end
    end

    describe "#compliance_requirements" do
      it "returns empty array when no requirements" do
        service_type = build(:service_type, :basic_cleaning)
        expect(service_type.compliance_requirements).to eq([])
      end

      it "includes background check requirement" do
        service_type = build(:service_type, requires_background_check: true)
        expect(service_type.compliance_requirements).to include("Background check required")
      end

      it "includes minimum staff requirement" do
        service_type = build(:service_type, min_staff_ratio: 2.0)
        expect(service_type.compliance_requirements).to include("Minimum 2.0 staff members")
      end

      it "includes compliance tracking for elderly care" do
        service_type = create(:service_type, :companion_care)
        expect(service_type.compliance_requirements).to include("Compliance tracking enabled")
      end

      it "includes all applicable requirements" do
        service_type = create(:service_type, :full_day_care)
        requirements = service_type.compliance_requirements

        expect(requirements).to include("Background check required")
        expect(requirements).to include("Minimum 2.0 staff members")
        expect(requirements).to include("Compliance tracking enabled")
      end
    end
  end

  describe ".create_defaults_for_vertical" do
    context "for cleaning vertical" do
      let(:vertical) { create(:vertical, :cleaning) }

      it "creates default cleaning service types" do
        expect { ServiceType.create_defaults_for_vertical(vertical) }
          .to change { vertical.service_types.count }.by(4)
      end

      it "creates Basic House Cleaning" do
        ServiceType.create_defaults_for_vertical(vertical)
        expect(vertical.service_types.find_by(name: "Basic House Cleaning")).to be_present
      end

      it "creates Deep Cleaning" do
        ServiceType.create_defaults_for_vertical(vertical)
        expect(vertical.service_types.find_by(name: "Deep Cleaning")).to be_present
      end
    end

    context "for elderly_care vertical" do
      let(:vertical) { create(:vertical, :elderly_care) }

      it "creates default elderly care service types" do
        expect { ServiceType.create_defaults_for_vertical(vertical) }
          .to change { vertical.service_types.count }.by(4)
      end

      it "creates Companion Care with background check requirement" do
        ServiceType.create_defaults_for_vertical(vertical)
        service = vertical.service_types.find_by(name: "Companion Care")

        expect(service).to be_present
        expect(service.requires_background_check).to be true
      end

      it "creates 24-Hour Care with multi-staff requirement" do
        ServiceType.create_defaults_for_vertical(vertical)
        service = vertical.service_types.find_by(name: "24-Hour Care")

        expect(service).to be_present
        expect(service.min_staff_ratio).to eq(2.0)
      end
    end

    context "for tutoring vertical" do
      let(:vertical) { create(:vertical, :tutoring) }

      it "creates default tutoring service types" do
        expect { ServiceType.create_defaults_for_vertical(vertical) }
          .to change { vertical.service_types.count }.by(4)
      end

      it "creates tutoring services with background check required" do
        ServiceType.create_defaults_for_vertical(vertical)

        vertical.service_types.each do |service|
          expect(service.requires_background_check).to be true
        end
      end
    end

    context "idempotency" do
      let(:vertical) { create(:vertical, :cleaning) }

      it "does not create duplicates when called twice" do
        ServiceType.create_defaults_for_vertical(vertical)
        expect { ServiceType.create_defaults_for_vertical(vertical) }
          .not_to change { vertical.service_types.count }
      end
    end
  end
end
