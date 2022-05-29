---
title: "Go global variables"
description: "When to use global variables in Go"
date: 2022-05-27T10:00:00-06:00
tags: ["go"]
---

Let's face it. Global variables are mostly bad and you should not use them.

BUT they are cases where it's better to use them. This post will explore these.

## Sentinel errors

In Go, you don't *throw* and *catch* errors.

You wrap and return them, and check them with `errors.Is(err, errSomething)`.

You may wonder what `errSomething` is? It's a **sentinel error**.

The error check `errors.Is(err, errSomething)` will return `true` only if `errSomething` is the **same** error variable as `err` or as the one wrapped in `err`.

That means in we would get in this code example:

```go
errTest := errors.New("test error")

err := fmt.Errorf("some context: %w", errTest)

fmt.Println(errors.Is(err, errTest)) // true
fmt.Println(errors.Is(err, errors.New("test error"))) // false
fmt.Println(errors.Is(err, errors.New("some context: test error"))) // false
```

As you can see, you need the actual same variable for `errors.Is` to work.

And... that's why we need **sentinel errors defined as global variables**.

On top of this, unless you handle the error within a package (log it out or take some other action), you should **export** the sentinel errors. A more concrete example would be:

```go
package store

import (
    "errors"
    "fmt"
)

var ErrUserIDNotFound = errors.New("user id not found")

func (s *Store) GetUser(userID string) (user User, err error) {
    user, ok := s.idToUser[userID]
    if !ok {
        return user, fmt.Errorf("%w: %s", ErrUserIDNotFound, userID)
    }
    return user, nil
}
```

And a user of this package would use:

```go
package main

import (
    "errors"
    "fmt"
    "os"
)

func main() {
    store := store.New()
    const userID = "123"
    user, err := store.GetUser(userID)
    if errors.Is(err, store.ErrUserIDNotFound) { // <- we need the error exported at global scope!
        fmt.Println("id not in here dawg")
        os.Exit(1)
    } else if err != nil {
        fmt.Println("error:", err)
        os.Exit(1)
    }

    fmt.Println("user found:", user)
}
```

Note `errors.Is(err, store.ErrUserIDNotFound)` which is the important code piece here, highlighting why sentinel errors have to be exported and defined at global scope.

If you are interested into errors wrapping, you can check out my other post *Wrap Go errors like it's Christmas!*.

## Regex

The standard library `regexp` package can compile regular expressions using two ways:

1. `regexp.Compile(str string) (r *regexp.Regexp, err error)`
2. `regexp.MustCompile(str string) *regexp.Regexp`

Now two additional facts to consider:

- Compiling a regular expression takes some time
- A compiled regular expression is immutable

Therefore, as soon as you have a **constant regular expression string**, you should have its compiled regular expression as a **global variable** (unexported by default). For example:

```go
package main

import (
  "regexp"
)


var regexAlphaNumeric = regexp.MustCompile(`^[a-zA-Z0-9_]+$`)

func isAlphaNumeric(s string) (ok bool) {
    return regexAlphaNumeric.MatchString(s)
}
```

This allows to compile the regex **only once**, and also to detect any regular expression issue at program start time (or by running a test importing this package).

**However**, do not define regular expressions with a variable string expression as global variables, and use `regexp.Compile` instead, checking its error.

## Variables set by the build pipeline

You can set global variable values from the `go build` command. For example:

`main.go`:

```go
package main

var version = "unknown"
```

using the build command:

```sh
go build -ldflags="-X 'main.version=test-1'" main.go
```

will set the global variable `version` to `"test-1"`.

Unfortunately, there is no way around using global variables in this case.

## Beware of these

### Caser

Since Go 1.18, `strings.Title` is now deprecated.
It was tempting to have the newer `*caser.Caser` at global scope:

```go
package main

import (
  "golang.org/x/text/cases"
  "golang.org/x/text/language"
)

var titleCaser = cases.Title(language.English)

func process(s string) string {
    return titleCaser.String(s)
}
```

To avoid re-creating a Title `cases.Caser` on every call to `process`.

However, `caser.Caser` is stateful and NOT thread safe. Therefore it gets messy quicky, even running parallel subtest will make it panic your code.

So don't have it as a global variable!

## High performance byte slices

You might think that having a global scope byte slice would yield higher performance? Benchmark, unless it's megabytes, it won't make a difference with a locally defined byte slice.

If you want a globally accessibly 'byte slice', have the byte slice data as a constant string and convert it where needed to a byte slice. In example:

```go
package main

import "bytes"

const globalConstant = "global constant"

func main() {
    _ = bytes.Count([]byte(globalConstant), []byte{1})
}
```

## Conclusion

Global variables are bad. But a necessary evil for sentinel errors
There are use cases for immutable variables (like regex) where it makes sense to use as well.
But otherwise, don't use them 😉
