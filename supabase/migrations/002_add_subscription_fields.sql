-- UniStream: Add subscription fields for RevenueCat integration
-- Run after configuring RevenueCat webhook

ALTER TABLE user_accounts
  ADD COLUMN IF NOT EXISTS revenuecat_customer_id text,
  ADD COLUMN IF NOT EXISTS subscription_platform text,
  ADD COLUMN IF NOT EXISTS subscription_product_id text;

-- Index for webhook lookups by RevenueCat customer ID
CREATE INDEX IF NOT EXISTS idx_accounts_revenuecat
  ON user_accounts(revenuecat_customer_id)
  WHERE revenuecat_customer_id IS NOT NULL;
