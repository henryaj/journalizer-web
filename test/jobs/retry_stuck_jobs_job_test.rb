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

    assert_enqueued_with(job: CheckOcrProgressJob, args: [ job.id ]) do
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

    assert_enqueued_with(job: PostProcessJob, args: [ job.id ]) do
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

  test "re-enqueues uploads for pages left mid-upload by a killed worker" do
    job = TranscriptionJob.create!(
      user: @user,
      status: "uploading",
      page_count: 2,
      user_job_number: 97,
      updated_at: 1.hour.ago
    )
    wedged = job.job_pages.create!(page_number: 1, status: "uploaded", updated_at: 1.hour.ago)
    job.job_pages.create!(page_number: 2, status: "ocr_complete",
                          handwriting_ocr_doc_id: "abc123", updated_at: 1.hour.ago)

    assert_enqueued_with(job: UploadToOcrJob, args: [ wedged.id ]) do
      RetryStuckJobsJob.perform_now
    end
  end

  test "leaves pages that actually reached the OCR API alone" do
    job = TranscriptionJob.create!(
      user: @user,
      status: "uploading",
      page_count: 1,
      user_job_number: 96,
      updated_at: 1.hour.ago
    )
    job.job_pages.create!(page_number: 1, status: "uploaded",
                          handwriting_ocr_doc_id: "abc123", updated_at: 1.hour.ago)

    assert_no_enqueued_jobs(only: UploadToOcrJob) do
      RetryStuckJobsJob.perform_now
    end
  end

  test "touches the job so the next sweep does not pile up another retry" do
    job = TranscriptionJob.create!(
      user: @user,
      status: "processing",
      user_job_number: 95,
      updated_at: 1.hour.ago
    )

    RetryStuckJobsJob.perform_now
    assert_operator job.reload.updated_at, :>, 1.minute.ago

    assert_no_enqueued_jobs(only: CheckOcrProgressJob) do
      RetryStuckJobsJob.perform_now
    end
  end
end
