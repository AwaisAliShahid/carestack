# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customer, type: :model do
  describe "associations" do
    let(:customer) { create(:customer) }

    it "belongs to an account" do
      expect(customer.account).to be_a(Account)
    end
  end

  describe "factory" do
    it "creates a valid customer" do
      customer = build(:customer)
      expect(customer).to be_valid
    end

    it "creates customer with location data" do
      customer = create(:customer)

      expect(customer.latitude).to be_present
      expect(customer.longitude).to be_present
      expect(customer.geocoded_address).to be_present
    end

    it "creates downtown customer with correct coordinates" do
      customer = create(:customer, :downtown)

      expect(customer.latitude).to eq(53.5461)
      expect(customer.longitude).to eq(-113.4938)
    end

    it "creates customer without location" do
      customer = create(:customer, :without_location)

      expect(customer.latitude).to be_nil
      expect(customer.longitude).to be_nil
    end
  end

  describe "#full_name" do
    it "combines first and last name" do
      customer = build(:customer, first_name: "John", last_name: "Doe")
      expect(customer.full_name).to eq("John Doe")
    end

    it "handles blank first name" do
      customer = build(:customer, first_name: "", last_name: "Doe")
      expect(customer.full_name).to eq(" Doe")
    end

    it "handles blank last name" do
      customer = build(:customer, first_name: "John", last_name: "")
      expect(customer.full_name).to eq("John ")
    end
  end

  describe "location traits" do
    it "creates customer in west Edmonton" do
      customer = create(:customer, :west_edmonton)

      expect(customer.latitude).to eq(53.5232)
      expect(customer.longitude).to eq(-113.5263)
      expect(customer.address).to eq("West Edmonton")
    end

    it "creates customer in south Edmonton" do
      customer = create(:customer, :south_edmonton)

      expect(customer.latitude).to eq(53.4668)
      expect(customer.longitude).to eq(-113.5114)
    end
  end

  describe "data integrity" do
    let(:account) { create(:account) }

    it "is destroyed when account is destroyed" do
      customer = create(:customer, account: account)
      account.destroy

      expect { customer.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
