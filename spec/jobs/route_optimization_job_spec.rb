# frozen_string_literal: true

require "rails_helper"

RSpec.describe RouteOptimizationJob, type: :job do
  include ActiveJob::TestHelper

  let(:vertical) { create(:vertical, :cleaning) }
  let(:account) { create(:account, vertical: vertical) }
  let(:service_type) { create(:service_type, vertical: vertical, duration_minutes: 120) }
  let(:staff) do
    create(:staff,
           account: account,
           background_check_passed: true,
           home_latitude: 53.5461,
           home_longitude: -113.4938,
           max_travel_radius_km: 30)
  end
  let(:customer) do
    create(:customer,
           account: account,
           latitude: 53.5401,
           longitude: -113.5065)
  end

  let!(:appointment) do
    create(:appointment,
           account: account,
           staff: staff,
           customer: customer,
           service_type: service_type,
           scheduled_at: Date.current.beginning_of_day + 9.hours,
           status: "confirmed")
  end

  let(:optimization_job) do
    OptimizationJob.create!(
      account: account,
      requested_date: Date.current,
      status: "pending",
      parameters: {
        "optimization_type" => "minimize_travel_time",
        "staff_ids" => []
      }
    )
  end

  describe "#perform" do
    it "processes a pending optimization job to completion" do
      described_class.perform_now(optimization_job.id)
      optimization_job.reload

      expect(optimization_job.status).to eq("completed")
    end

    it "sets processing timestamps" do
      described_class.perform_now(optimization_job.id)
      optimization_job.reload

      expect(optimization_job.processing_started_at).to be_present
      expect(optimization_job.processing_completed_at).to be_present
    end

    it "creates routes for the optimization" do
      expect {
        described_class.perform_now(optimization_job.id)
      }.to change { Route.count }.by_at_least(1)
    end

    it "associates routes with the optimization job" do
      described_class.perform_now(optimization_job.id)
      optimization_job.reload

      expect(optimization_job.routes.count).to be >= 1
    end

    it "stores result metrics" do
      described_class.perform_now(optimization_job.id)
      optimization_job.reload

      expect(optimization_job.result).to be_present
      expect(optimization_job.result).to include("routes_created")
      expect(optimization_job.result).to include("total_appointments")
    end

    context "when job is already completed" do
      before { optimization_job.update!(status: "completed") }

      it "skips processing" do
        expect(SimpleRouteOptimizerService).not_to receive(:new)
        described_class.perform_now(optimization_job.id)
      end
    end

    context "when job is already failed" do
      before { optimization_job.update!(status: "failed") }

      it "skips processing" do
        expect(SimpleRouteOptimizerService).not_to receive(:new)
        described_class.perform_now(optimization_job.id)
      end
    end

    context "when there are no appointments" do
      before { Appointment.destroy_all }

      it "marks the job as failed" do
        described_class.perform_now(optimization_job.id)
        optimization_job.reload

        expect(optimization_job.status).to eq("failed")
        expect(optimization_job.result["error"]).to include("No appointments")
      end
    end

    context "when an exception occurs during optimization" do
      before do
        # Simulate an error after the service is created
        allow_any_instance_of(SimpleRouteOptimizerService)
          .to receive(:optimize!)
          .and_raise(StandardError.new("Database connection lost"))
      end

      it "marks the job as failed" do
        # The job catches the exception, marks as failed, then re-raises
        # In test mode, the exception may be swallowed by ActiveJob
        begin
          described_class.perform_now(optimization_job.id)
        rescue StandardError
          # Expected - job re-raises for retry
        end

        optimization_job.reload
        expect(optimization_job.status).to eq("failed")
        expect(optimization_job.result["error"]).to eq("Database connection lost")
      end
    end
  end

  describe "job configuration" do
    it "uses the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end

    it "can be enqueued" do
      expect {
        described_class.perform_later(optimization_job.id)
      }.to have_enqueued_job(described_class).with(optimization_job.id)
    end
  end

  describe "integration with GraphQL async mode" do
    it "processes jobs created by async mutation" do
      # Simulate what the GraphQL mutation does in async mode
      async_job = OptimizationJob.create!(
        account: account,
        requested_date: Date.current,
        status: "pending",
        parameters: {
          "optimization_type" => "minimize_travel_time",
          "staff_ids" => [ staff.id ]
        }
      )

      # Process the job
      described_class.perform_now(async_job.id)
      async_job.reload

      expect(async_job.status).to eq("completed")
      expect(async_job.routes).not_to be_empty
    end
  end
end
