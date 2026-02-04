require "test_helper"

class RetryStuckJobsJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
  end

  test "re-enqueues CheckOcrProgressJob for jobs stuck in processing" do
    job = TranscriptionJob.create!(
      user: @user,
      status: "processing",
      user_job_number: 99,
      updated_at: 1.hour.ago
    )

    assert_enqueued_with(job: CheckOcrProgressJob, args: [job.id]) do
      RetryStuckJobsJob.perform_now
    end
  end

  test "re-enqueues PostProcessJob for jobs stuck in post_processing" do
    job = TranscriptionJob.create!(
      user: @user,
      status: "post_processing",
      user_job_number: 99,
      updated_at: 1.hour.ago
    )

    assert_enqueued_with(job: PostProcessJob, args: [job.id]) do
      RetryStuckJobsJob.perform_now
    end
  end

  test "does not retry jobs updated within threshold" do
    job = TranscriptionJob.create!(
      user: @user,
      status: "processing",
      user_job_number: 99,
      updated_at: 10.minutes.ago
    )

    assert_no_enqueued_jobs do
      RetryStuckJobsJob.perform_now
    end
  end

  test "does not retry completed or failed jobs" do
    TranscriptionJob.create!(
      user: @user,
      status: "completed",
      user_job_number: 98,
      updated_at: 1.hour.ago
    )

    TranscriptionJob.create!(
      user: @user,
      status: "failed",
      user_job_number: 99,
      updated_at: 1.hour.ago
    )

    assert_no_enqueued_jobs do
      RetryStuckJobsJob.perform_now
    end
  end
end
