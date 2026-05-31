-- Fix the collection trigger to properly iterate through EMIs one at a time,
-- marking only as many as the collected amount covers (overdue → current → advance).
-- Previously it marked ALL unpaid EMIs in a single batch update.

CREATE OR REPLACE FUNCTION public.update_schedule_on_collection()
RETURNS TRIGGER AS $$
DECLARE
    v_remaining_amount DECIMAL(12, 2);
    v_emi_record RECORD;
    v_current_outstanding DECIMAL(12, 2);
    v_total_repayable DECIMAL(12, 2);
    v_emi_cursor CURSOR FOR 
        SELECT id, emi_amount 
        FROM public.emi_schedule 
        WHERE loan_id = NEW.loan_id 
          AND is_paid = false 
          AND paid_on IS NULL
        ORDER BY emi_number ASC;
BEGIN
    -- Only proceed for loan collections
    IF NEW.loan_id IS NOT NULL THEN
        v_remaining_amount := NEW.amount_collected;
        
        -- Iterate through unpaid EMIs oldest first, marking as many as the amount covers
        FOR v_emi_record IN v_emi_cursor LOOP
            EXIT WHEN v_remaining_amount <= 0;
            
            IF v_remaining_amount >= v_emi_record.emi_amount THEN
                -- Full payment of this EMI
                UPDATE public.emi_schedule
                SET 
                    is_paid = true,
                    status = 'paid',
                    paid_on = (NEW.collection_date + NEW.collection_time)::timestamptz,
                    payment_mode = COALESCE(NEW.payment_mode, payment_mode)
                WHERE id = v_emi_record.id;
                
                v_remaining_amount := v_remaining_amount - v_emi_record.emi_amount;
            ELSE
                -- Partial payment — don't mark as paid
                v_remaining_amount := 0;
            END IF;
        END LOOP;
    END IF;
    
    -- Update loan outstanding amount and outstanding balance
    IF NEW.loan_id IS NOT NULL THEN
        SELECT 
            COALESCE(outstanding_balance, outstanding_amount, total_repayable, amount, 0),
            COALESCE(total_repayable, amount, 0)
        INTO v_current_outstanding, v_total_repayable
        FROM public.loans
        WHERE id = NEW.loan_id;
        
        IF v_current_outstanding <= 0 THEN
            v_current_outstanding := v_total_repayable;
        END IF;

        UPDATE public.loans
        SET 
            outstanding_amount = GREATEST(v_current_outstanding - NEW.amount_collected, 0),
            outstanding_balance = GREATEST(v_current_outstanding - NEW.amount_collected, 0),
            status = CASE 
                WHEN v_current_outstanding - NEW.amount_collected <= 0 THEN 'closed'
                ELSE status
            END
        WHERE id = NEW.loan_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
