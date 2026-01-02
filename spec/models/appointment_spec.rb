# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appointment, type: :model do
  describe "associations" do
    let(:appointment) { create(:appointment) }

    it "belongs to an account" do
      expect(appointment.account).to be_a(Account)
    end

    it "belongs to a customer" do
      expect(appointment.customer).to be_a(Customer)
    end

    it "belongs to a service_type" do
      expect(appointment.service_type).to be_a(ServiceType)
    end

    it "belongs to a staff member" do
      expect(appointment.staff).to be_a(Staff)
    end
  end

  describe "factory" do
    it "creates a valid appointment" do
      appointment = build(:appointment)
      expect(appointment).to be_valid
    end

    it "creates appointment with proper associations" do
      appointment = create(:appointment)

      expect(appointment.customer.account).to eq(appointment.account)
      expect(appointment.staff.account).to eq(appointment.account)
      expect(appointment.service_type.vertical).to eq(appointment.account.vertical)
    end

    it "sets default status to scheduled" do
      appointment = create(:appointment)
      expect(appointment.status).to eq("scheduled")
    end

    it "sets duration from service type" do
      service_type = create(:service_type, duration_minutes: 180)
      appointment = create(:appointment, service_type: service_type)

      expect(appointment.duration_minutes).to eq(180)
    end
  end

  describe "status traits" do
    it "creates scheduled appointment" do
      appointment = create(:appointment, :scheduled)
      expect(appointment.status).to eq("scheduled")
    end

    it "creates confirmed appointment" do
      appointment = create(:appointment, :confirmed)
      expect(appointment.status).to eq("confirmed")
    end

    it "creates in_progress appointment" do
      appointment = create(:appointment, :in_progress)
      expect(appointment.status).to eq("in_progress")
    end

    it "creates completed appointment" do
      appointment = create(:appointment, :completed)
      expect(appointment.status).to eq("completed")
    end

    it "creates cancelled appointment" do
      appointment = create(:appointment, :cancelled)
      expect(appointment.status).to eq("cancelled")
    end
  end

  describe "scheduling traits" do
    it "creates appointment for today" do
      Timecop.freeze(Time.current) do
        appointment = create(:appointment, :today)
        expect(appointment.scheduled_at.to_date).to eq(Date.current)
      end
    end

    it "creates appointment for tomorrow" do
      Timecop.freeze(Time.current) do
        appointment = create(:appointment, :tomorrow)
        expect(appointment.scheduled_at.to_date).to eq(Date.current + 1.day)
      end
    end
  end

  describe "vertical-specific appointments" do
    describe "cleaning appointments" do
      it "creates appointment with cleaning service type" do
        appointment = create(:appointment, :cleaning_appointment)

        expect(appointment.account.cleaning?).to be true
        expect(appointment.service_type.cleaning?).to be true
      end
    end

    describe "elderly care appointments" do
      it "creates appointment with elderly care service type" do
        appointment = create(:appointment, :elderly_care_appointment)

        expect(appointment.account.elderly_care?).to be true
        expect(appointment.service_type.elderly_care?).to be true
      end

      it "creates appointment with background-checked staff" do
        appointment = create(:appointment, :elderly_care_appointment)
        expect(appointment.staff.background_check_passed).to be true
      end
    end
  end

  describe "integration with account" do
    let(:account) { create(:account) }

    it "is included in account active_appointments when scheduled" do
      appointment = create(:appointment, :scheduled, account: account)
      expect(account.active_appointments).to include(appointment)
    end

    it "is included in account active_appointments when in_progress" do
      appointment = create(:appointment, :in_progress, account: account)
      expect(account.active_appointments).to include(appointment)
    end

    it "is not included in account active_appointments when completed" do
      appointment = create(:appointment, :completed, account: account)
      expect(account.active_appointments).not_to include(appointment)
    end

    it "is not included in account active_appointments when cancelled" do
      appointment = create(:appointment, :cancelled, account: account)
      expect(account.active_appointments).not_to include(appointment)
    end
  end

  describe "data integrity" do
    let(:account) { create(:account) }

    it "is destroyed when account is destroyed" do
      appointment = create(:appointment, account: account)
      account.destroy

      expect { appointment.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "is destroyed when service_type is destroyed" do
      service_type = create(:service_type)
      appointment = create(:appointment, service_type: service_type)
      service_type.destroy

      expect { appointment.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "querying by date" do
    let(:account) { create(:account) }

    it "can find appointments for a specific date" do
      Timecop.freeze(Date.current) do
        today_appointment = create(:appointment, :today, account: account)
        create(:appointment, :tomorrow, account: account)

        today_start = Date.current.beginning_of_day
        today_end = Date.current.end_of_day

        appointments = account.appointments.where(scheduled_at: today_start..today_end)
        expect(appointments).to eq([today_appointment])
      end
    end
  end
end
