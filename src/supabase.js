import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const SUPABASE_URL = 'https://dqspufskkgoszwvkpeox.supabase.co';
export const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable__JSIgAlJrSZHPFv2FMXtgA_D5po0UM7';
export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
