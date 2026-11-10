-- Migration 010: Add user_group column to users table
-- Groups: super_admin, network, general_user

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS user_group TEXT NOT NULL DEFAULT 'general_user';

-- Add a CHECK constraint for valid group values
ALTER TABLE users
  ADD CONSTRAINT users_group_check
  CHECK (user_group IN ('super_admin', 'network', 'general_user'));
