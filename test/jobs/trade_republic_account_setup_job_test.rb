require "test_helper"

class TradeRepublicAccountSetupJobTest < ActiveJob::TestCase
  setup do
    @item = trade_republic_items(:configured_item)
  end

  test "processes account history before scheduling the provider sync" do
    sequence = sequence("account setup")
    @item.expects(:process_accounts).in_sequence(sequence).returns([ { success: true } ])
    @item.expects(:sync_later).in_sequence(sequence)
    @item.stubs(:ready_for_sync?).returns(true)

    TradeRepublicAccountSetupJob.perform_now(@item)
  end

  test "schedules account syncs when the provider session is expired" do
    @item.update_columns(session_expires_at: 1.minute.ago)
    @item.stubs(:process_accounts).returns([ { success: true } ])
    @item.expects(:sync_later).never
    @item.expects(:schedule_account_syncs).once

    TradeRepublicAccountSetupJob.perform_now(@item)
  end

  test "does not schedule another sync when account processing fails" do
    @item.stubs(:process_accounts).returns([ { success: false, error: "bad event" } ])
    @item.expects(:sync_later).never
    @item.expects(:schedule_account_syncs).never

    assert_raises(RuntimeError) { TradeRepublicAccountSetupJob.perform_now(@item) }
  end

  test "does nothing for a connection scheduled for deletion" do
    @item.update_column(:scheduled_for_deletion, true)
    @item.expects(:process_accounts).never

    TradeRepublicAccountSetupJob.perform_now(@item)
  end
end
