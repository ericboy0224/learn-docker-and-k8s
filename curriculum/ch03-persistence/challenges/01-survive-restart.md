# Challenge 01: Survive the Restart

> **Difficulty:** Beginner
> **Estimated time:** 15–20 minutes

---

## Situation

Customer support just escalated ticket #4471 to engineering. A NoCappuccino subscriber spent twenty minutes building their perfect coffee profile — origin preferences, roast level, brewing method, grind size — and it all disappeared after Dave's routine maintenance restart.

Dave's response: "I just ran `docker rm` and then `docker run` again. How was I supposed to know that would delete everything?"

This is your chance to fix it so it never happens again.

---

## Your Mission

Run a MySQL container with a **named volume** so the database survives container deletion. Prove that data written before the container is removed still exists after the container is recreated.

---

## Requirements

1. Create a named volume called **`learn-ch03-db-data`** with the labels `app=learn-docker-k8s` and `chapter=ch03`.

2. Run a MySQL 8.0 container named **`learn-ch03-mysql`** with:
   - Labels: `app=learn-docker-k8s` and `chapter=ch03`
   - The named volume mounted at `/var/lib/mysql`
   - Environment variables: `MYSQL_ROOT_PASSWORD=cloudbrewsecret` and `MYSQL_DATABASE=preferences`

3. Connect to MySQL and create a table with at least one row of data:
   - Database: `preferences`
   - Table: `customers`
   - At least one `INSERT` statement

4. **Stop and remove the container** (not just stop — actually `docker rm` it).

5. Recreate the container using the **same volume and same configuration** as step 2.

6. Connect to MySQL again and verify that the table and data from step 3 are still there.

---

## Success Condition

Running `verify.sh` outputs:
```
PASS: Volume 'learn-ch03-db-data' exists
PASS: Container 'learn-ch03-mysql' is running
PASS: Table 'customers' exists in 'preferences' database
PASS: Table 'customers' has at least 1 row

All checks passed! Challenge complete!
```

---

## Hints

<details>
<summary>Hint 1 — Getting started</summary>

The `-v` flag is how you attach a volume. Think about what order you need: does the volume need to exist before you run the container, or can Docker create it automatically on first use? Try both and observe the difference.

When the container first starts, MySQL needs a moment to initialize the database. Give it 10–20 seconds before trying to connect.

</details>

<details>
<summary>Hint 2 — Connecting to MySQL</summary>

You can get an interactive MySQL shell inside the container using `docker exec`. The flags you need are `-it` for interactive terminal access, and the command is `mysql` with the appropriate `-u` (user) and `-p` (password) flags.

Once inside, the SQL commands you need are:
- `USE preferences;` to select the database
- `CREATE TABLE ... ;` to create a table
- `INSERT INTO ... ;` to add a row
- `SELECT * FROM ... ;` to verify

</details>

<details>
<summary>Hint 3 — The destroy-and-recreate sequence</summary>

The exact sequence that proves persistence is:

1. Write data (while the container is running)
2. `docker stop learn-ch03-mysql`
3. `docker rm learn-ch03-mysql`
4. Run `docker ps -a` — confirm the container is gone
5. Run `docker volume ls` — confirm the volume still exists
6. `docker run` with the same `-v learn-ch03-db-data:/var/lib/mysql` flag
7. Connect and verify the data

If you see MySQL trying to initialize a fresh database on step 6, the volume is not attached correctly — it would only initialize from scratch if it sees an empty `/var/lib/mysql` directory.

</details>

---

## Post-Challenge Reflection

Once your verify script passes, think about these questions:

- What would happen if you used `-v /var/lib/mysql` (no volume name) instead of `-v learn-ch03-db-data:/var/lib/mysql`?
- Where does Docker actually store the files for `learn-ch03-db-data`? Run `docker volume inspect learn-ch03-db-data` and look at the `Mountpoint`.
- If this were a production database, what else would you add beyond a volume? (Think: backups, replication, monitoring.)

---

## Resources

- `docker volume create --help`
- `docker volume inspect`
- `docker run --help` (look for the `-v` / `--volume` section)
- [Lesson 02: Volumes and Mounts](../lessons/02-volumes-and-mounts.md)
- [Lesson 03: Volume Lifecycle](../lessons/03-volume-lifecycle.md)
