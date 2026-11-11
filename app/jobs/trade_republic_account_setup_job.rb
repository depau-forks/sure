# Import stored account history after the HTTP setup request has redirected.
# Share the provider lock with regular syncs, which may run concurrently.
class TradeRepublicAccountSetupJob < ApplicationJob
  queue_as :default

  def perform(trade_republic_item)
    Time.use_zone(trade_republic_item.family.resolved_time_zone) do
      trade_republic_item.with_account_processing_lock do
        return if trade_republic_item.reload.scheduled_for_deletion?

        results = trade_republic_item.process_accounts
        failed = results.count { !_1[:success] }
        raise "Trade Republic account setup processing failed for #{failed} account(s)" if failed.positive?

        return if results.empty?
      end

      if trade_republic_item.reload.ready_for_sync?
        trade_republic_item.sync_later
      else
        trade_republic_item.schedule_account_syncs
      end
    end
  end
end
