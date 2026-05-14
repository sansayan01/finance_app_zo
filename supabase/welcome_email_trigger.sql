-- Create a function to send welcome email on user creation
CREATE OR REPLACE FUNCTION public.send_welcome_email_on_signup()
RETURNS TRIGGER AS $$
DECLARE
  org_name text;
  user_email text;
BEGIN
  -- Extract user email from the new auth user
  user_email := NEW.email;
  
  -- Get organization name from the profiles table (assuming it's linked via org_id)
  -- or from the organization associated with this user
  SELECT o.name INTO org_name
  FROM profiles p
  JOIN organizations o ON p.org_id = o.id
  WHERE p.id = NEW.id
  LIMIT 1;
  
  -- If no organization found via profiles, try to get it from the user's direct org_id if exists
  IF org_name IS NULL THEN
    SELECT o.name INTO org_name
    FROM organizations o
    WHERE o.id = NEW.raw_user_meta_data->>'org_id'
    LIMIT 1;
  END IF;
  
  -- Default organization name if none found
  IF org_name IS NULL THEN
    org_name := 'MicroFlow Pro';
  END IF;
  
  -- Call the edge function to send the email
  PERFORM net.http_post(
    'https://' || current_setting('supabase.projectId') || '.functions.supabase.co/send-welcome-email',
    json_build_object(
      'email', user_email,
      'orgName', org_name,
      'userId', NEW.id
    )::text,
    headers := ARRAY[
      'Authorization', 'Bearer ' || current_setting('supabase.anon_key'),
      'Content-Type', 'application/json'
    ]
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to call the function after insert on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.send_welcome_email_on_signup();