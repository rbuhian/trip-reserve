-- Fix: create_driver_earnings trigger runs in the caller's security context
-- (the driver), which is blocked by RLS since drivers have no INSERT policy on
-- driver_earnings. Recreating as SECURITY DEFINER so it runs as the function
-- owner (postgres) and bypasses RLS.

CREATE OR REPLACE FUNCTION create_driver_earnings()
RETURNS TRIGGER AS $$
DECLARE
  platform_fee_percent DECIMAL := 15.00;
  gross DECIMAL;
  fee DECIMAL;
  net DECIMAL;
BEGIN
  IF NEW.status = 'completed' AND OLD.status = 'in_progress' THEN
    gross := NEW.total_amount;
    fee := gross * (platform_fee_percent / 100);
    net := gross - fee;

    INSERT INTO driver_earnings (
      driver_id,
      booking_id,
      gross_amount,
      platform_fee,
      net_amount,
      status
    ) VALUES (
      NEW.driver_id,
      NEW.id,
      gross,
      fee,
      net,
      'pending'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
