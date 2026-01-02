# frozen_string_literal: true

require "rails_helper"

RSpec.describe OptimizationJob, type: :model do
  describe "validations" do
    subject { build(:optimization_job) }

    it { is_expected.to be_valid }

    describe "requested_date" do
      it "is required" do
        subject.requested_date = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:requested_date]).to include("can't be blank")
      end
    end

    describe "status" do
      it "is required" do
        subject.status = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:status]).to include("can't be blank")
      end

      it "must be a valid status" do
        subject.status = "invalid_status"
        expect(subject).not_to be_valid
        expect(subject.errors[:status]).to include("is not included in the list")
      end

      %w[pending processing completed failed].each do |valid_status|
        it "accepts '#{valid_status}' as valid status" do
          subject.status = valid_status
          expect(subject).to be_valid
        end
      end
    end
  end

  describe "associations" do
    let(:optimization_job) { create(:optimization_job) }

    it "belongs to an account" do
      expect(optimization_job.account).to be_a(Account)
    end
  end

  describe "scopes" do
    describe ".recent" do
      it "returns jobs from the last week" do
        recent_job = create(:optimization_job, created_at: 3.days.ago)
        create(:optimization_job, created_at: 2.weeks.ago)

        expect(OptimizationJob.recent).to eq([recent_job])
      end
    end

    describe ".for_date" do
      it "returns jobs for the specified date" do
        today_job = create(:optimization_job, requested_date: Date.current)
        create(:optimization_job, requested_date: Date.current + 1.day)

        expect(OptimizationJob.for_date(Date.current)).to eq([today_job])
      end
    end
  end

  describe "instance methods" do
    describe "#processing_time_seconds" do
      it "calculates processing time when both timestamps exist" do
        job = build(:optimization_job,
          processing_started_at: Time.current - 30.seconds,
          processing_completed_at: Time.current
        )
        expect(job.processing_time_seconds).to be_within(1).of(30)
      end

      it "returns nil when started_at is missing" do
        job = build(:optimization_job,
          processing_started_at: nil,
          processing_completed_at: Time.current
        )
        expect(job.processing_time_seconds).to be_nil
      end

      it "returns nil when completed_at is missing" do
        job = build(:optimization_job,
          processing_started_at: Time.current,
          processing_completed_at: nil
        )
        expect(job.processing_time_seconds).to be_nil
      end
    end

    describe "#success?" do
      it "returns true when status is completed" do
        job = build(:optimization_job, status: "completed")
        expect(job.success?).to be true
      end

      it "returns false for other statuses" do
        %w[pending processing failed].each do |status|
          job = build(:optimization_job, status: status)
          expect(job.success?).to be false
        end
      end
    end

    describe "#failed?" do
      it "returns true when status is failed" do
        job = build(:optimization_job, status: "failed")
        expect(job.failed?).to be true
      end

      it "returns false for other statuses" do
        %w[pending processing completed].each do |status|
          job = build(:optimization_job, status: status)
          expect(job.failed?).to be false
        end
      end
    end

    describe "#processing?" do
      it "returns true when status is processing" do
        job = build(:optimization_job, status: "processing")
        expect(job.processing?).to be true
      end

      it "returns false for other statuses" do
        %w[pending completed failed].each do |status|
          job = build(:optimization_job, status: status)
          expect(job.processing?).to be false
        end
      end
    end

    describe "#time_savings" do
      it "returns time saved from result when successful" do
        job = create(:optimization_job, :completed)
        expect(job.time_savings).to eq(1.5)
      end

      it "returns nil when not successful" do
        job = create(:optimization_job, :failed)
        expect(job.time_savings).to be_nil
      end

      it "returns nil when result is empty" do
        job = create(:optimization_job, status: "completed", result: {})
        expect(job.time_savings).to be_nil
      end
    end

    describe "#cost_savings" do
      it "returns cost savings from result when successful" do
        job = create(:optimization_job, :completed)
        expect(job.cost_savings).to eq(37.50)
      end

      it "returns nil when not successful" do
        job = create(:optimization_job, :pending)
        expect(job.cost_savings).to be_nil
      end

      it "returns nil when result is missing cost_savings" do
        job = create(:optimization_job, status: "completed", result: { "time_saved_hours" => 1.0 })
        expect(job.cost_savings).to be_nil
      end
    end

    describe "#routes_created" do
      it "returns routes count from result when successful" do
        job = create(:optimization_job, :completed)
        expect(job.routes_created).to eq(2)
      end

      it "returns 0 when not successful" do
        job = create(:optimization_job, :pending)
        expect(job.routes_created).to eq(0)
      end

      it "returns 0 when result is missing routes_created" do
        job = create(:optimization_job, status: "completed", result: {})
        expect(job.routes_created).to eq(0)
      end
    end
  end

  describe "factory traits" do
    it "creates pending job" do
      job = create(:optimization_job, :pending)
      expect(job.status).to eq("pending")
      expect(job.processing_started_at).to be_nil
    end

    it "creates processing job" do
      job = create(:optimization_job, :processing)
      expect(job.status).to eq("processing")
      expect(job.processing_started_at).to be_present
      expect(job.processing_completed_at).to be_nil
    end

    it "creates completed job with result data" do
      job = create(:optimization_job, :completed)
      expect(job.status).to eq("completed")
      expect(job.result["routes_created"]).to eq(2)
      expect(job.result["time_saved_hours"]).to eq(1.5)
    end

    it "creates failed job with error message" do
      job = create(:optimization_job, :failed)
      expect(job.status).to eq("failed")
      expect(job.result["error"]).to be_present
    end
  end

  describe "parameter traits" do
    it "creates job with minimize_travel_time parameters" do
      job = create(:optimization_job, :minimize_travel_time)
      # JSON columns convert symbol keys to strings
      expect(job.parameters["optimization_type"]).to eq("minimize_travel_time")
    end

    it "creates job with minimize_cost parameters" do
      job = create(:optimization_job, :minimize_cost)
      expect(job.parameters["optimization_type"]).to eq("minimize_total_cost")
    end

    it "creates job with balance_workload parameters" do
      job = create(:optimization_job, :balance_workload)
      expect(job.parameters["optimization_type"]).to eq("balance_workload")
    end
  end
end
