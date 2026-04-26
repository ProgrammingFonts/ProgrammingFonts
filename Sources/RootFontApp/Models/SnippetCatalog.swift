import Foundation

enum SnippetStrategy: String, CaseIterable, Identifiable, Sendable {
    case semantic
    case native

    var id: Self { self }
}

enum SnippetCatalog {
    static func snippet(language: MiniTokenizer.Language, strategy: SnippetStrategy) -> String {
        switch strategy {
        case .semantic:
            return semanticSnippet(language: language)
        case .native:
            return nativeSnippet(language: language)
        }
    }

    private static func semanticSnippet(language: MiniTokenizer.Language) -> String {
        switch language {
        case .swift:
            return """
            import Foundation

            struct User {
                let id: Int
                let name: String
            }

            func greet(_ user: User) -> String {
                return "Hello, \\(user.name)!"
            }
            """
        case .typescript:
            return """
            interface User { id: number; name: string }

            const greet = (user: User): string => {
              return `Hello, ${user.name}!`;
            };
            """
        case .javascript:
            return """
            /**
             * @param {{id:number,name:string}} user
             */
            function greet(user) {
              return `Hello, ${user.name}!`;
            }
            """
        case .python:
            return """
            from dataclasses import dataclass

            @dataclass
            class User:
                id: int
                name: str

            def greet(user: User) -> str:
                return f"Hello, {user.name}!"
            """
        case .rust:
            return """
            struct User { id: u64, name: String }

            fn greet(user: &User) -> String {
                format!("Hello, {}!", user.name)
            }
            """
        case .go:
            return """
            package main

            type User struct { ID int; Name string }

            func Greet(user User) string {
                return fmt.Sprintf("Hello, %s!", user.Name)
            }
            """
        case .java:
            return """
            record User(int id, String name) {}

            class Greeter {
              static String greet(User user) {
                return "Hello, " + user.name() + "!";
              }
            }
            """
        case .kotlin:
            return """
            data class User(val id: Int, val name: String)

            fun greet(user: User): String {
                return "Hello, ${user.name}!"
            }
            """
        case .sql:
            return """
            SELECT id, name
            FROM users
            WHERE id = :user_id;
            """
        case .json:
            return """
            {
              "user": { "id": 42, "name": "RootFont" },
              "message": "Hello, RootFont!"
            }
            """
        case .shell:
            return """
            #!/usr/bin/env bash
            set -euo pipefail

            user_name="RootFont"
            echo "Hello, ${user_name}!"
            """
        case .css:
            return """
            .user-card {
              font-family: "JetBrains Mono", monospace;
              --user-name-color: #268bd2;
            }
            """
        }
    }

    private static func nativeSnippet(language: MiniTokenizer.Language) -> String {
        switch language {
        case .swift:
            return """
            actor CacheStore<Key: Hashable, Value> {
                private var storage: [Key: Value] = [:]

                func value(for key: Key) -> Value? { storage[key] }
                func set(_ value: Value, for key: Key) { storage[key] = value }
            }
            """
        case .typescript:
            return """
            export type HttpMethod = "GET" | "POST" | "PATCH";

            export async function request<T>(url: string, method: HttpMethod): Promise<T> {
              const response = await fetch(url, { method });
              return (await response.json()) as T;
            }
            """
        case .javascript:
            return """
            const debounce = (fn, wait = 120) => {
              let timer;
              return (...args) => {
                clearTimeout(timer);
                timer = setTimeout(() => fn(...args), wait);
              };
            };
            """
        case .python:
            return """
            from contextlib import contextmanager

            @contextmanager
            def transaction(conn):
                try:
                    yield conn
                    conn.commit()
                except Exception:
                    conn.rollback()
                    raise
            """
        case .rust:
            return """
            use std::collections::HashMap;

            fn count_words(line: &str) -> HashMap<String, usize> {
                let mut counts = HashMap::new();
                for word in line.split_whitespace() {
                    *counts.entry(word.to_string()).or_insert(0) += 1;
                }
                counts
            }
            """
        case .go:
            return """
            package worker

            import "context"

            func Run(ctx context.Context, jobs <-chan string) error {
                for {
                    select {
                    case <-ctx.Done():
                        return ctx.Err()
                    case job := <-jobs:
                        _ = job
                    }
                }
            }
            """
        case .java:
            return """
            import java.time.Instant;

            public final class AuditEvent {
              private final String action;
              private final Instant occurredAt;

              public AuditEvent(String action, Instant occurredAt) {
                this.action = action;
                this.occurredAt = occurredAt;
              }
            }
            """
        case .kotlin:
            return """
            sealed interface ApiResult<out T> {
                data class Success<T>(val value: T): ApiResult<T>
                data class Failure(val code: Int, val reason: String): ApiResult<Nothing>
            }
            """
        case .sql:
            return """
            WITH ranked_events AS (
              SELECT user_id, event_type, created_at,
                     ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn
              FROM audit_events
            )
            SELECT user_id, event_type, created_at
            FROM ranked_events
            WHERE rn <= 5;
            """
        case .json:
            return """
            {
              "editor": {
                "fontFamily": "JetBrains Mono",
                "fontSize": 14,
                "fontLigatures": true
              }
            }
            """
        case .shell:
            return """
            #!/usr/bin/env bash
            set -euo pipefail

            for file in "$@"; do
              [ -f "$file" ] || continue
              echo "processing: $file"
            done
            """
        case .css:
            return """
            :root {
              --panel-bg: #111827;
              --panel-border: #374151;
            }

            .code-panel {
              border: 1px solid var(--panel-border);
              background: var(--panel-bg);
            }
            """
        }
    }
}
