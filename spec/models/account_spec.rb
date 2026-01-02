# frozen_string_literal: true

require "rails_helper"

RSpec.describe Account, type: :model do
  describe "validations" do
    subject { build(:account) }

    it { is_expected.to be_valid }

    describe "name" do
      it "is required" do
        subject.name = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:name]).to include("can't be blank")
      end
    end

    describe "email" do
      it "is required" do
        subject.email = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:email]).to include("can't be blank")
      end

      it "must be a valid email format" do
        subject.email = "invalid-email"
        expect(subject).not_to be_valid
        expect(subject.errors[:email]).to include("is invalid")
      end

      it "accepts valid email formats" do
        subject.email = "valid@example.com"
        expect(subject).to be_valid
      end
    end

    describe "phone" do
      it "is required" do
        subject.phone = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:phone]).to include("can't be blank")
      end
    end
  end

  describe "associations" do
    let(:account) { create(:account) }

    it "belongs to a vertical" do
      expect(account.vertical).to be_a(Vertical)
    end

    it "has many customers" do
      customer = create(:customer, account: account)
      expect(account.customers).to include(customer)
    end

    it "has many staff members" do
      staff = create(:staff, account: account)
      expect(account.staff).to include(staff)
    end

    it "has many appointments" do
      appointment = create(:appointment, account: account)
      expect(account.appointments).to include(appointment)
    end

    it "destroys customers when account is destroyed" do
      create(:customer, account: account)
      expect { account.destroy }.to change(Customer, :count).by(-1)
    end

    it "destroys staff when account is destroyed" do
      create(:staff, account: account)
      expect { account.destroy }.to change(Staff, :count).by(-1)
    end
  end

  describe "scopes" do
    describe ".for_vertical" do
      it "returns accounts for the specified vertical slug" do
        cleaning_vertical = create(:vertical, :cleaning)
        elderly_vertical = create(:vertical, :elderly_care)

        cleaning_account = create(:account, vertical: cleaning_vertical)
        create(:account, vertical: elderly_vertical)

        expect(Account.for_vertical("cleaning")).to eq([cleaning_account])
      end
    end

    describe ".cleaning_services" do
      it "returns only cleaning service accounts" do
        cleaning_account = create(:account, :cleaning_business)
        create(:account, :elderly_care_business)

        expect(Account.cleaning_services).to eq([cleaning_account])
      end
    end

    describe ".elderly_care_services" do
      it "returns only elderly care accounts" do
        create(:account, :cleaning_business)
        elderly_account = create(:account, :elderly_care_business)

        expect(Account.elderly_care_services).to eq([elderly_account])
      end
    end
  end

  describe "delegations" do
    let(:cleaning_account) { create(:account, :cleaning_business) }
    let(:elderly_care_account) { create(:account, :elderly_care_business) }

    describe "#vertical_display_name" do
      it "delegates to vertical" do
        expect(cleaning_account.vertical_display_name).to eq(cleaning_account.vertical.display_name)
      end
    end

    describe "#requires_compliance_tracking?" do
      it "returns false for cleaning" do
        expect(cleaning_account.requires_compliance_tracking?).to be false
      end

      it "returns true for elderly_care" do
        expect(elderly_care_account.requires_compliance_tracking?).to be true
      end
    end

    describe "#requires_background_checks?" do
      it "returns false for cleaning" do
        expect(cleaning_account.requires_background_checks?).to be false
      end

      it "returns true for elderly_care" do
        expect(elderly_care_account.requires_background_checks?).to be true
      end
    end

    describe "#cleaning?" do
      it "returns true for cleaning account" do
        expect(cleaning_account.cleaning?).to be true
      end

      it "returns false for elderly_care account" do
        expect(elderly_care_account.cleaning?).to be false
      end
    end

    describe "#elderly_care?" do
      it "returns false for cleaning account" do
        expect(cleaning_account.elderly_care?).to be false
      end

      it "returns true for elderly_care account" do
        expect(elderly_care_account.elderly_care?).to be true
      end
    end
  end

  describe "instance methods" do
    let(:account) { create(:account) }

    describe "#display_name_with_vertical" do
      it "returns name with vertical in parentheses" do
        expect(account.display_name_with_vertical).to eq("#{account.name} (#{account.vertical_display_name})")
      end
    end

    describe "#total_customers" do
      it "returns the count of customers" do
        create_list(:customer, 3, account: account)
        expect(account.total_customers).to eq(3)
      end

      it "returns 0 when no customers" do
        expect(account.total_customers).to eq(0)
      end
    end

    describe "#total_staff" do
      it "returns the count of staff" do
        create_list(:staff, 2, account: account)
        expect(account.total_staff).to eq(2)
      end

      it "returns 0 when no staff" do
        expect(account.total_staff).to eq(0)
      end
    end

    describe "#active_appointments" do
      it "returns only scheduled and in_progress appointments" do
        scheduled = create(:appointment, :scheduled, account: account)
        in_progress = create(:appointment, :in_progress, account: account)
        create(:appointment, :completed, account: account)
        create(:appointment, :cancelled, account: account)

        expect(account.active_appointments).to contain_exactly(scheduled, in_progress)
      end
    end

    describe "#completed_appointments_this_month" do
      it "returns completed appointments from current month" do
        Timecop.freeze(Time.current.beginning_of_month + 15.days) do
          this_month = create(:appointment, :completed, account: account, scheduled_at: 5.days.ago)
          create(:appointment, :completed, account: account, scheduled_at: 2.months.ago)
          create(:appointment, :scheduled, account: account)

          expect(account.completed_appointments_this_month).to eq([this_month])
        end
      end
    end
  end

  describe "business rules" do
    describe "#can_schedule_appointment?" do
      let(:cleaning_account) { create(:account, :cleaning_business) }
      let(:elderly_care_account) { create(:account, :elderly_care_business) }

      context "with cleaning vertical" do
        let(:service_type) { create(:service_type, vertical: cleaning_account.vertical) }

        it "returns true for matching vertical without background check requirement" do
          expect(cleaning_account.can_schedule_appointment?(service_type, 1)).to be true
        end

        it "returns false when service type is from different vertical" do
          other_vertical = create(:vertical, :elderly_care)
          other_service = create(:service_type, vertical: other_vertical)

          expect(cleaning_account.can_schedule_appointment?(other_service, 1)).to be false
        end
      end

      context "with elderly_care vertical" do
        let(:service_type) { create(:service_type, :companion_care, vertical: elderly_care_account.vertical) }

        it "returns false when staff have not passed background checks" do
          create(:staff, :not_background_checked, account: elderly_care_account)

          expect(elderly_care_account.can_schedule_appointment?(service_type, 1)).to be false
        end

        it "returns true when all staff have passed background checks" do
          create(:staff, :background_checked, account: elderly_care_account)

          expect(elderly_care_account.can_schedule_appointment?(service_type, 1)).to be true
        end

        context "with min_staff_ratio requirement" do
          let(:multi_staff_service) { create(:service_type, :full_day_care, vertical: elderly_care_account.vertical) }

          before do
            create(:staff, :background_checked, account: elderly_care_account)
          end

          it "returns false when staff_count is below minimum" do
            expect(elderly_care_account.can_schedule_appointment?(multi_staff_service, 1)).to be false
          end

          it "returns true when staff_count meets minimum" do
            expect(elderly_care_account.can_schedule_appointment?(multi_staff_service, 2)).to be true
          end
        end
      end
    end

    describe "#compliance_status" do
      context "when compliance tracking is not required" do
        let(:cleaning_account) { create(:account, :cleaning_business) }

        it "returns :not_required" do
          expect(cleaning_account.compliance_status).to eq(:not_required)
        end
      end

      context "when compliance tracking is required (elderly_care)" do
        let(:elderly_care_account) { create(:account, :elderly_care_business) }

        it "returns compliance hash with background check counts" do
          create(:staff, :background_checked, account: elderly_care_account)
          create(:staff, :not_background_checked, account: elderly_care_account)

          status = elderly_care_account.compliance_status

          expect(status[:background_checks]).to eq(1)
          expect(status[:total_staff]).to eq(2)
          expect(status[:compliance_rate]).to eq(50.0)
        end

        it "returns 0 compliance rate when no staff" do
          status = elderly_care_account.compliance_status

          expect(status[:compliance_rate]).to eq(0.0)
        end

        it "returns 100% when all staff have background checks" do
          create_list(:staff, 3, :background_checked, account: elderly_care_account)

          status = elderly_care_account.compliance_status

          expect(status[:compliance_rate]).to eq(100.0)
        end
      end
    end
  end
end
