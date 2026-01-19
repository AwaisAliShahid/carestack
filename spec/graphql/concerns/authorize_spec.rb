# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authorize do
  let(:test_class) do
    Class.new do
      include Authorize

      attr_accessor :context

      def initialize(context)
        @context = context
      end
    end
  end

  let(:account) { create(:account) }
  let(:other_account) { create(:account) }

  describe "#authenticate!" do
    context "when user is logged in" do
      let(:user) { create(:user, account: account) }
      let(:instance) { test_class.new({ current_user: user }) }

      it "does not raise an error" do
        expect { instance.send(:authenticate!) }.not_to raise_error
      end
    end

    context "when user is not logged in" do
      let(:instance) { test_class.new({ current_user: nil }) }

      it "raises AuthenticationError" do
        expect { instance.send(:authenticate!) }.to raise_error(Authorize::AuthenticationError)
      end
    end
  end

  describe "#authorize_account_access!" do
    context "when user belongs to the account" do
      let(:user) { create(:user, account: account) }
      let(:instance) { test_class.new({ current_user: user }) }

      it "returns the account" do
        result = instance.send(:authorize_account_access!, account.id)
        expect(result).to eq(account)
      end
    end

    context "when user does not belong to the account" do
      let(:user) { create(:user, account: other_account) }
      let(:instance) { test_class.new({ current_user: user }) }

      it "raises AuthorizationError" do
        expect { instance.send(:authorize_account_access!, account.id) }
          .to raise_error(Authorize::AuthorizationError)
      end
    end

    context "when user is a super admin (no account)" do
      let(:user) { create(:user, account: nil, role: "admin") }
      let(:instance) { test_class.new({ current_user: user }) }

      it "returns the account" do
        result = instance.send(:authorize_account_access!, account.id)
        expect(result).to eq(account)
      end
    end

    context "when user is not logged in" do
      let(:instance) { test_class.new({ current_user: nil }) }

      it "raises AuthenticationError" do
        expect { instance.send(:authorize_account_access!, account.id) }
          .to raise_error(Authorize::AuthenticationError)
      end
    end
  end

  describe "#can_access_account?" do
    context "when user belongs to the account" do
      let(:user) { create(:user, account: account) }
      let(:instance) { test_class.new({ current_user: user }) }

      it "returns true" do
        expect(instance.send(:can_access_account?, account)).to be true
      end
    end

    context "when user does not belong to the account" do
      let(:user) { create(:user, account: other_account) }
      let(:instance) { test_class.new({ current_user: user }) }

      it "returns false" do
        expect(instance.send(:can_access_account?, account)).to be false
      end
    end

    context "when user is a super admin" do
      let(:user) { create(:user, account: nil, role: "admin") }
      let(:instance) { test_class.new({ current_user: user }) }

      it "returns true for any account" do
        expect(instance.send(:can_access_account?, account)).to be true
        expect(instance.send(:can_access_account?, other_account)).to be true
      end
    end
  end

  describe "#authorize_manager!" do
    context "when user is a manager" do
      let(:user) { create(:user, account: account, role: "manager") }
      let(:instance) { test_class.new({ current_user: user }) }

      it "does not raise an error" do
        expect { instance.send(:authorize_manager!) }.not_to raise_error
      end
    end

    context "when user is an admin" do
      let(:user) { create(:user, account: account, role: "admin") }
      let(:instance) { test_class.new({ current_user: user }) }

      it "does not raise an error" do
        expect { instance.send(:authorize_manager!) }.not_to raise_error
      end
    end

    context "when user is a regular member" do
      let(:user) { create(:user, account: account, role: "member") }
      let(:instance) { test_class.new({ current_user: user }) }

      it "raises AuthorizationError" do
        expect { instance.send(:authorize_manager!) }
          .to raise_error(Authorize::AuthorizationError)
      end
    end
  end
end
