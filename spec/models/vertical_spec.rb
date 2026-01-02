# frozen_string_literal: true

require "rails_helper"

RSpec.describe Vertical, type: :model do
  describe "validations" do
    subject { build(:vertical) }

    it { is_expected.to be_valid }

    describe "name" do
      it "is required" do
        subject.name = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:name]).to include("can't be blank")
      end
    end

    describe "slug" do
      it "is required" do
        subject.slug = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:slug]).to include("can't be blank")
      end

      it "must be unique" do
        create(:vertical, slug: "cleaning")
        subject.slug = "cleaning"
        expect(subject).not_to be_valid
        expect(subject.errors[:slug]).to include("has already been taken")
      end
    end

    describe "active" do
      it "must be a boolean" do
        subject.active = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:active]).to include("is not included in the list")
      end

      it "accepts true" do
        subject.active = true
        expect(subject).to be_valid
      end

      it "accepts false" do
        subject.active = false
        expect(subject).to be_valid
      end
    end
  end

  describe "associations" do
    it "has many accounts" do
      vertical = create(:vertical)
      account1 = create(:account, vertical: vertical)
      account2 = create(:account, vertical: vertical)

      expect(vertical.accounts).to include(account1, account2)
    end

    it "has many service_types" do
      vertical = create(:vertical)
      service1 = create(:service_type, vertical: vertical)
      service2 = create(:service_type, vertical: vertical)

      expect(vertical.service_types).to include(service1, service2)
    end

    it "destroys associated accounts when destroyed" do
      vertical = create(:vertical)
      create(:account, vertical: vertical)

      expect { vertical.destroy }.to change(Account, :count).by(-1)
    end

    it "destroys associated service_types when destroyed" do
      vertical = create(:vertical)
      create(:service_type, vertical: vertical)

      expect { vertical.destroy }.to change(ServiceType, :count).by(-1)
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active verticals" do
        active = create(:vertical, active: true)
        create(:vertical, :inactive)

        expect(Vertical.active).to eq([active])
      end
    end
  end

  describe "vertical type checks" do
    describe "#cleaning?" do
      it "returns true for cleaning vertical" do
        vertical = build(:vertical, :cleaning)
        expect(vertical.cleaning?).to be true
      end

      it "returns false for non-cleaning vertical" do
        vertical = build(:vertical, :elderly_care)
        expect(vertical.cleaning?).to be false
      end
    end

    describe "#elderly_care?" do
      it "returns true for elderly_care vertical" do
        vertical = build(:vertical, :elderly_care)
        expect(vertical.elderly_care?).to be true
      end

      it "returns false for non-elderly_care vertical" do
        vertical = build(:vertical, :cleaning)
        expect(vertical.elderly_care?).to be false
      end
    end

    describe "#tutoring?" do
      it "returns true for tutoring vertical" do
        vertical = build(:vertical, :tutoring)
        expect(vertical.tutoring?).to be true
      end

      it "returns false for non-tutoring vertical" do
        vertical = build(:vertical, :cleaning)
        expect(vertical.tutoring?).to be false
      end
    end

    describe "#home_repair?" do
      it "returns true for home_repair vertical" do
        vertical = build(:vertical, :home_repair)
        expect(vertical.home_repair?).to be true
      end

      it "returns false for non-home_repair vertical" do
        vertical = build(:vertical, :cleaning)
        expect(vertical.home_repair?).to be false
      end
    end
  end

  describe "compliance requirements" do
    describe "#requires_compliance_tracking?" do
      it "returns true for elderly_care" do
        vertical = build(:vertical, :elderly_care)
        expect(vertical.requires_compliance_tracking?).to be true
      end

      it "returns false for cleaning" do
        vertical = build(:vertical, :cleaning)
        expect(vertical.requires_compliance_tracking?).to be false
      end

      it "returns false for tutoring" do
        vertical = build(:vertical, :tutoring)
        expect(vertical.requires_compliance_tracking?).to be false
      end
    end

    describe "#requires_background_checks?" do
      it "returns true for elderly_care" do
        vertical = build(:vertical, :elderly_care)
        expect(vertical.requires_background_checks?).to be true
      end

      it "returns true for tutoring" do
        vertical = build(:vertical, :tutoring)
        expect(vertical.requires_background_checks?).to be true
      end

      it "returns false for cleaning" do
        vertical = build(:vertical, :cleaning)
        expect(vertical.requires_background_checks?).to be false
      end

      it "returns false for home_repair" do
        vertical = build(:vertical, :home_repair)
        expect(vertical.requires_background_checks?).to be false
      end
    end
  end

  describe "#display_name" do
    it "returns the name when present" do
      vertical = build(:vertical, name: "Cleaning Services", slug: "cleaning")
      expect(vertical.display_name).to eq("Cleaning Services")
    end

    it "returns titleized slug when name is blank" do
      vertical = build(:vertical, name: "", slug: "elderly_care")
      expect(vertical.display_name).to eq("Elderly Care")
    end

    it "returns titleized slug when name is nil" do
      vertical = build(:vertical, slug: "home_repair")
      vertical.name = nil
      expect(vertical.display_name).to eq("Home Repair")
    end
  end
end
