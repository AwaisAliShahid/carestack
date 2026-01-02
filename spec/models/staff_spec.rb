# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff, type: :model do
  describe "associations" do
    let(:staff) { create(:staff) }

    it "belongs to an account" do
      expect(staff.account).to be_a(Account)
    end
  end

  describe "factory" do
    it "creates a valid staff member" do
      staff = build(:staff)
      expect(staff).to be_valid
    end

    it "creates staff with home location" do
      staff = create(:staff)

      expect(staff.home_latitude).to be_present
      expect(staff.home_longitude).to be_present
    end

    it "creates staff without background check by default" do
      staff = create(:staff)
      expect(staff.background_check_passed).to be false
    end

    it "creates staff with background check using trait" do
      staff = create(:staff, :background_checked)
      expect(staff.background_check_passed).to be true
    end
  end

  describe "#full_name" do
    it "combines first and last name" do
      staff = build(:staff, first_name: "Jane", last_name: "Smith")
      expect(staff.full_name).to eq("Jane Smith")
    end

    it "handles blank first name" do
      staff = build(:staff, first_name: "", last_name: "Smith")
      expect(staff.full_name).to eq(" Smith")
    end

    it "handles blank last name" do
      staff = build(:staff, first_name: "Jane", last_name: "")
      expect(staff.full_name).to eq("Jane ")
    end
  end

  describe "background check traits" do
    it "creates staff with passed background check" do
      staff = create(:staff, :background_checked)
      expect(staff.background_check_passed).to be true
    end

    it "creates staff without passed background check" do
      staff = create(:staff, :not_background_checked)
      expect(staff.background_check_passed).to be false
    end
  end

  describe "location traits" do
    it "creates downtown-based staff" do
      staff = create(:staff, :downtown_based)

      expect(staff.home_latitude).to eq(53.5461)
      expect(staff.home_longitude).to eq(-113.4938)
    end

    it "creates west-based staff" do
      staff = create(:staff, :west_based)

      expect(staff.home_latitude).to eq(53.5232)
      expect(staff.home_longitude).to eq(-113.5263)
    end
  end

  describe "travel radius traits" do
    it "creates staff with limited radius" do
      staff = create(:staff, :limited_radius)
      expect(staff.max_travel_radius_km).to eq(10)
    end

    it "creates staff with wide radius" do
      staff = create(:staff, :wide_radius)
      expect(staff.max_travel_radius_km).to eq(50)
    end

    it "creates staff with default radius" do
      staff = create(:staff)
      expect(staff.max_travel_radius_km).to eq(25)
    end
  end

  describe "data integrity" do
    let(:account) { create(:account) }

    it "is destroyed when account is destroyed" do
      staff = create(:staff, account: account)
      account.destroy

      expect { staff.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "elderly care compliance" do
    let(:elderly_care_account) { create(:account, :elderly_care_business) }

    it "affects account compliance status when background check is passed" do
      create(:staff, :background_checked, account: elderly_care_account)

      status = elderly_care_account.compliance_status
      expect(status[:compliance_rate]).to eq(100.0)
    end

    it "affects account compliance status when background check is not passed" do
      create(:staff, :not_background_checked, account: elderly_care_account)

      status = elderly_care_account.compliance_status
      expect(status[:compliance_rate]).to eq(0.0)
    end
  end
end
