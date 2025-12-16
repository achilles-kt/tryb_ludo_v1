import { db } from "../admin";

/**
 * Generic Queue Processor
 * Handles the "Lock -> Fetch -> Claim" pattern for any queue.
 */
export const QueueManager = {

    /**
     * Tries to acquire a lock for a specific queue path.
     * @param lockName e.g., "queue/2p" or "queue/4p_solo"
     * @param timeoutMs Duration before lock is considered stale (default 10s)
     * @returns boolean - true if lock acquired
     */
    async acquireLock(lockName: string, timeoutMs = 10000): Promise<boolean> {
        const lockPath = `locks/${lockName}`;
        const ref = db.ref(lockPath);

        const res = await ref.transaction((current) => {
            if (current && (Date.now() - current < timeoutMs)) {
                return; // Active lock exists
            }
            return Date.now(); // Claim it
        });

        return res.committed;
    },

    /**
     * Releases a lock.
     */
    async releaseLock(lockName: string) {
        await db.ref(`locks/${lockName}`).remove();
    },

    /**
     * Atomically claims a queue entry to prevent double-matching.
     * @param queuePath e.g., "queue/2p"
     * @param key The pushId of the entry
     * @param uid The UID to verify (optional safety check)
     * @returns The entry data if successfully claimed, null otherwise.
     */
    async claimEntry(queuePath: string, key: string, uid?: string): Promise<any | null> {
        const ref = db.ref(`${queuePath}/${key}`);
        let claimedVal: any = null;

        await ref.transaction((current) => {
            if (current === null) return current; // Retry if local cache miss
            if (uid && String(current.uid) !== String(uid)) return undefined; // Mismatch

            claimedVal = current;
            return null; // Remove from queue (Claimed)
        });

        return claimedVal;
    },

    /**
     * Restores an entry if matchmaking failed after claiming.
     */
    async restoreEntry(queuePath: string, key: string, data: any) {
        if (!data) return;
        console.warn(`↩️ QUEUE_RESTORE: Restoring ${key} to ${queuePath}`);
        await db.ref(`${queuePath}/${key}`).set(data);
    }
};
