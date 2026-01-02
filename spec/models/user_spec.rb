# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to be_valid }

    it "requires first_name" do
      subject.first_name = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:first_name]).to include("can't be blank")
    end

    it "requires last_name" do
      subject.last_name = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:last_name]).to include("can't be blank")
    end

    it "requires email" do
      subject.email = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:email]).to include("can't be blank")
    end

    it "requires unique email" do
      create(:user, email: "test@example.com")
      subject.email = "test@example.com"
      expect(subject).not_to be_valid
      expect(subject.errors[:email]).to include("has already been taken")
    end

    it "requires valid role" do
      subject.role = "invalid_role"
      expect(subject).not_to be_valid
      expect(subject.errors[:role]).to include("is not included in the list")
    end

    it "accepts valid roles" do
      %w[admin manager member].each do |role|
        subject.role = role
        expect(subject).to be_valid
      end
    end
  end

  describe "associations" do
    it "belongs to account (optional)" do
      user = build(:user, account: nil)
      expect(user).to be_valid
    end

    it "can be associated with an account" do
      account = create(:account)
      user = create(:user, account: account)
      expect(user.account).to eq(account)
    end
  end

  describe "#full_name" do
    it "returns first and last name combined" do
      user = build(:user, first_name: "John", last_name: "Doe")
      expect(user.full_name).to eq("John Doe")
    end
  end

  describe "role methods" do
    describe "#admin?" do
      it "returns true for admin role" do
        expect(build(:user, :admin).admin?).to be true
      end

      it "returns false for non-admin role" do
        expect(build(:user, :member).admin?).to be false
      end
    end

    describe "#manager?" do
      it "returns true for manager role" do
        expect(build(:user, :manager).manager?).to be true
      end

      it "returns false for non-manager role" do
        expect(build(:user, :member).manager?).to be false
      end
    end

    describe "#member?" do
      it "returns true for member role" do
        expect(build(:user, :member).member?).to be true
      end

      it "returns false for non-member role" do
        expect(build(:user, :admin).member?).to be false
      end
    end

    describe "#can_manage_account?" do
      it "returns true for admin" do
        expect(build(:user, :admin).can_manage_account?).to be true
      end

      it "returns true for manager" do
        expect(build(:user, :manager).can_manage_account?).to be true
      end

      it "returns false for member" do
        expect(build(:user, :member).can_manage_account?).to be false
      end
    end
  end

  describe "scopes" do
    let!(:admin) { create(:user, :admin) }
    let!(:manager) { create(:user, :manager) }
    let!(:member) { create(:user, :member) }

    it ".admins returns only admins" do
      expect(User.admins).to contain_exactly(admin)
    end

    it ".managers returns only managers" do
      expect(User.managers).to contain_exactly(manager)
    end

    it ".members returns only members" do
      expect(User.members).to contain_exactly(member)
    end

    describe ".for_account" do
      let(:account) { create(:account) }
      let!(:account_user) { create(:user, account: account) }

      it "returns users for the specified account" do
        expect(User.for_account(account)).to contain_exactly(account_user)
      end
    end
  end

  describe "Devise authentication" do
    let(:user) { create(:user, password: "securepassword123", password_confirmation: "securepassword123") }

    it "validates password on creation" do
      user = build(:user, password: "short", password_confirmation: "short")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("is too short (minimum is 6 characters)")
    end

    it "authenticates with correct password" do
      expect(user.valid_password?("securepassword123")).to be true
    end

    it "does not authenticate with incorrect password" do
      expect(user.valid_password?("wrongpassword")).to be false
    end
  end
end
