-- Clean up broken auth identities and users
DELETE FROM auth.identities WHERE user_id IN (
  SELECT id FROM auth.users WHERE email IN (
    'testadmin@microflow.com', 'manager@gmail.com', 'collection@gmail.com', 'customer@gmail.com',
    'freshuser@microflow.com', 'test_verify@microflow.com', 'newtest@microflow.com'
  )
);
DELETE FROM auth.sessions WHERE user_id IN (
  SELECT id FROM auth.users WHERE email IN (
    'testadmin@microflow.com', 'manager@gmail.com', 'collection@gmail.com', 'customer@gmail.com',
    'freshuser@microflow.com', 'test_verify@microflow.com', 'newtest@microflow.com'
  )
);
DELETE FROM auth.users WHERE email IN (
  'testadmin@microflow.com', 'manager@gmail.com', 'collection@gmail.com', 'customer@gmail.com',
  'freshuser@microflow.com', 'test_verify@microflow.com', 'newtest@microflow.com'
);
