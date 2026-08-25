# How a latchkey connector works (for a non-technical reader)

A single analogy carried the whole way through. Read this if the procedure doc
made your eyes glaze over.

## The one analogy: a valet key for your car

Your car is the service — Outlook, DocuSign, Slack, whatever. You own the car,
so you have the real key: your username and password. A **valet key** is a
limited copy. It can start the car and open the doors, but it can't open the
trunk or the glovebox — it can only do what you decided it's allowed to do.

A latchkey connector is the thing that **holds the valet key** and uses it on
behalf of an assistant (an AI agent), so the assistant can do things for you
without ever touching your real key.

## Why a valet key and not the real key

Two reasons, and only one of them is a nice principle:

1. **Revocable and scoped** (the good reason). You can hand the valet key out,
   watch what it does, and take it back — and it can never do more than you
   allowed. The assistant never sees your password. If something goes wrong,
   you revoke the valet key; you never have to change your password.
2. **The system has a bug-shaped behavior we work around** (the honest reason).
   There's a separate system that decides what each key is allowed to do —
   "this one can read mail but not send it." If a key gets handed out *before*
   its rule exists, it doesn't just fail that one action — it jams **every
   other key in the cabinet**. So we always write the rule first. That's not an
   elegant design choice; it's a workaround for a nasty failure mode, and it's
   worth saying so plainly. We write rules first because the alternative is a
   total lockout.

## The password is only for the first handoff

When you get a valet key made, you show up in person, prove you're the owner
(the username and password), and the locksmith cuts the copy. After that, the
valet key works on its own — the valet never needs your real key again.

Same here. The connector needs your real login **exactly once**, to mint the
stored valet key. It does not keep your password, it does not re-ask for it on
every use, and it never sends it anywhere. The only time you'd type your
password again is if the valet key expired and a new one needs cutting — and
even then, only if there's no way to silently refresh it (some services allow
a silent refresh; some don't, and those are the ones that periodically ask you
to re-confirm).

## What "building a connector" means in the car analogy

Building a connector is **teaching our valet stand to recognize and cut a new
brand of key** — nothing more. It's not modifying the car (we are not patching
Outlook or DocuSign). It's adding a new key blank and the instructions for
cutting it to *our own* inventory.

So the steps are:

1. **Look at the real car first.** Watch how the manufacturer actually hands
   out valet keys for this model — where the key gets cut, what it looks like,
   what it can and can't do. Don't guess from the manual; the manual has been
   wrong before.
2. **Practice cutting the key in a locked workshop**, not at the valet stand
   itself. We have a throwaway practice stand for this — no real cars, no real
   customers, no risk of jamming the real stand. Get the cutting perfect here
   first.
3. **Write the rule for what the key can do**, *before* any key exists. (See
   the bug above — this order is not optional.)
4. **Add the key blank to our stand's catalog** so it can be requested.
5. **Cut one real key, with you present for the one sign-in**, and watch it
   actually start a real car end-to-end. If it doesn't work, we debug in the
   workshop — we don't keep asking you to come back and re-sign-in.
6. **Make it official**: submit the key blank and its rule to the three
   projects that ship them to everyone, in order, and watch their automated
   checks pass.
7. **Remove the practice key from the real stand** once it's proven — leaving
   practice keys lying around is what caused the "every key jams" lockouts
   before.

## The "hot-mod" is not modifying the service

When we test the key before making it official, we patch **our own app** — the
Minds app on your Mac — to recognize the new key type. We are not breaking
into Outlook's building or changing their locks. It's exactly like adding a
new key blank to the valet stand's drawer, not like rekeying the car at the
factory.

And it's temporary: the practice key in the real stand gets removed once the
official version ships. In fact, every time the Minds app updates itself, it
wipes the practice drawer clean on its own — which is one more reason making
it official (step 6) matters more than perfecting the practice version.

## The philosophy in one line

Hand out scoped, revocable copies; never give up the real key; and be honest
that some of the "rules first" rigor is a workaround for a bug, not a virtue.
