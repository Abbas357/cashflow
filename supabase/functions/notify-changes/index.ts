// Cash Flow: pushes changes to shared accounts to the other members' phones,
// through Firebase Cloud Messaging (HTTP v1).
//
// The app calls this right after uploading entry history (entry_changes),
// with the ids it uploaded. Only the signed-in author's own changes are
// sent, and only to people who are active members of that account and
// have a phone registered in push_devices.
//
// Needs one secret, FIREBASE_SERVICE_ACCOUNT: the JSON key of a Firebase
// service account (Firebase console, Project settings, Service accounts,
// Generate new private key). Without it the function sends nothing.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'npm:jose@5';

type Change = {
  id: string;
  account_id: string;
  action: string;
  old_data: Record<string, unknown> | null;
  new_data: Record<string, unknown> | null;
  changed_by_name: string;
};

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const jwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const { data: auth } = await db.auth.getUser(jwt);
  const me = auth?.user;
  if (!me) return json({ error: 'Sign in first' }, 401);

  const serviceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!serviceAccount) return json({ sent: 0, reason: 'FIREBASE_SERVICE_ACCOUNT is not set' });

  const { change_ids: ids } = await req.json().catch(() => ({ change_ids: [] }));
  if (!Array.isArray(ids) || ids.length === 0) return json({ sent: 0 });

  const { data: changes } = await db
    .from('entry_changes')
    .select('id, account_id, action, old_data, new_data, changed_by_name')
    .in('id', ids.slice(0, 200))
    .eq('changed_by', me.id);
  if (!changes?.length) return json({ sent: 0 });

  const accountIds = [...new Set((changes as Change[]).map((c) => c.account_id))];
  const [{ data: accounts }, { data: members }] = await Promise.all([
    db.from('accounts').select('id, name').in('id', accountIds),
    db.from('account_members')
      .select('account_id, user_id')
      .in('account_id', accountIds)
      .eq('status', 'active')
      .neq('user_id', me.id),
  ]);
  const people = [...new Set((members ?? []).map((m) => m.user_id as string))];
  if (people.length === 0) return json({ sent: 0 });

  const { data: devices } = await db.from('push_devices').select('token, user_id').in('user_id', people);
  if (!devices?.length) return json({ sent: 0 });

  const account = JSON.parse(serviceAccount);
  const accessToken = await googleAccessToken(account);
  const endpoint = `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

  let sent = 0;
  const dead: string[] = [];
  for (const accountId of accountIds) {
    const list = (changes as Change[]).filter((c) => c.account_id === accountId);
    const title = accounts?.find((a) => a.id === accountId)?.name ?? 'A shared account';
    const body = list.length === 1
      ? describe(list[0])
      : `${[...new Set(list.map(who))].join(', ')} made ${list.length} changes`;
    const members_ = new Set((members ?? []).filter((m) => m.account_id === accountId).map((m) => m.user_id));

    for (const device of devices.filter((d) => members_.has(d.user_id))) {
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            token: device.token,
            notification: { title, body },
            data: { type: 'change', account_id: accountId },
            android: {
              priority: 'HIGH',
              // One notification per account: a newer one replaces it.
              notification: { channel_id: 'shared_changes', tag: accountId },
            },
          },
        }),
      });
      if (res.ok) {
        sent++;
      } else {
        const text = await res.text();
        // The phone uninstalled the app or the token expired: forget it.
        if (res.status === 404 || text.includes('UNREGISTERED')) dead.push(device.token);
        else console.error('FCM', res.status, text);
      }
    }
  }
  if (dead.length) await db.from('push_devices').delete().in('token', dead);
  return json({ sent });
});

function who(c: Change) {
  return c.changed_by_name?.trim() || 'Someone';
}

/// "Abbas added Cash Out 500: Milk". No currency symbol: each person picks
/// their own in the app.
function describe(c: Change) {
  const did = ({ created: 'added', updated: 'edited', deleted: 'deleted' } as Record<string, string>)[c.action] ??
    'changed';
  const data = (c.new_data ?? c.old_data ?? {}) as Record<string, unknown>;
  const kind = data.type === 'in' ? 'Cash In' : 'Cash Out';
  const amount = typeof data.amount === 'number'
    ? ` ${data.amount.toLocaleString('en-US', { maximumFractionDigits: 2 })}`
    : '';
  const note = typeof data.note === 'string' && data.note.trim() ? `: ${data.note.trim()}` : '';
  return `${who(c)} ${did} ${kind}${amount}${note}`;
}

/// An OAuth token for the FCM API, from the service account's key.
async function googleAccessToken(account: { client_email: string; private_key: string }) {
  const key = await importPKCS8(account.private_key, 'RS256');
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(account.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  const body = await res.json();
  if (!body.access_token) throw new Error(`Google token: ${JSON.stringify(body)}`);
  return body.access_token as string;
}
