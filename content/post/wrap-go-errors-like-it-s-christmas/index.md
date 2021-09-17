---
title: "Wrap Go errors like it's Christmas!"
description: "How to properly wrap errors in your Go projects"
date: 2021-09-15T15:00:00-06:00
tags: ["go", "errors"]
---

In a hurry 🏃? [**Jump to the conclusion**](#conclusion)

![Title](title.svg)

It took me months if not years to figure out the best way to wrap errors in Go.

This was even more critical when developing public Go APIs where a user should be able to check for your (returned) errors.

## Global variables and errors

**NEVER USE GLOBAL VARIABLES!...** except for errors which are meant to be *constants*.

For example:

```go
var ErrUserNotFound = errors.New("user not found")
```

Is perfectly fine. This is a bit the same treatment as:

```go
var _ = regexp.MustCompile("some constant string")
```

where global variables *should* be used.

We take this approach for:

- Clarity, where you usually define all the errors at the top of your Go file
- Performance, since this will not create the error every time the code path is hit
- Callers to be able to examine the returned error and programmatically check which one it is (see the [Wrap errors section](#wrap-errors))

## Return a new error

There are code paths where you want to return a 'new' error.

Take the function `GetUsers` below:

```go
package main

import (
    "errors"
)

type User struct {
    ID int
}

type MemoryDB interface {
    GetUsers() (users []User)
}

var ErrNoUserExist = errors.New("no user exist")

func GetUsers(db MemoryDB) (users []User, err error) {
    users = db.GetUsers()

    if len(users) == 0 {
        return nil, ErrNoUserExist
    }

    return users, nil
}
```

`GetUsers` returns a 'new' error `ErrNoUserExist` if no user are found.

Note we still use the globally defined error variables for this.

## Wrap errors

Consider the following function taking an address and returning its port as an integer.

```go
func getPortFromAddress(address string) (port int, err error) {
    _, portStr, err := net.SplitHostPort(address)
    if err != nil {
        return 0, err // note: bad, see below
    }

    port, err = strconv.Atoi(portStr)
    if err != nil {
        return 0, err // note: bad, see below
    }

    return port, nil
}
```

We may get an error either from `net.SplitHostPort` or from `strconv.Atoi`.

There are two problems with this no-wrapping approach:

1. There is no context wrapping the error so the human will have a harder time understanding where/why it failed.
1. Functions calling this function will have a hard time asserting programmatically what caused the error.

To solve this, define two global errors:

```go
var (
    errSplitHostPort    = errors.New("cannot split host and port from address")
    errPortNotAnInteger = errors.New("port is not an integer")
)
```

and modify the error returns to:

- Use those two defined errors as wrapping errors
- Add the original error as a string
- Add eventually more context, such as the address string or port string

```go
func getPortFromAddress(address string) (port int, err error) {
    _, portStr, err := net.SplitHostPort(address)
    if err != nil {
        return 0, fmt.Errorf("%w: %s: %s", errSplitHostPort, address, err)
    }

    port, err = strconv.Atoi(portStr)
    if err != nil {
        return 0, fmt.Errorf("%w: %s: %s", errPortNotAnInteger, portStr, err)
    }

    return port, nil
}
```

Now a caller can optionally programmatically check which error caused the failure to adjust its behavior.
For example:

```go
const address = "1.2.3.4:notAnInteger"
port, err := getPortFromAddress(address)
switch {
case err == nil: // continue execution
case errors.Is(err, errSplitHostPort):
    // Behavior when the address does not have
    // a colon separating address and port
case errors.Is(err, errPortNotAnInteger):
    // Behavior when the port is not an integer.
    // THIS IS THE ONE WHICH TRIGGERS IN THIS CASE.
default:
    // Behavior for the rest of the possible errors
}
```

Our two wrapping errors are **unexported** since the function is **unexported**.

If your function is exported, you must **export** your errors. For example:

```go
var (
    ErrSplitHostPort    = errors.New("cannot split host and port from address")
    ErrPortNotAnInteger = errors.New("port is not an integer")
)
```

Such that an external package can use them with for example:

```go
errors.Is(err, yourpackage.ErrSplitHostPort)
```

## Conclusion

1. Define your errors as global variables with `errors.New`
2. Wrap your errors with `fmt.Errorf("%w: %s: more context", ErrBlabla, err)`
3. Export your errors when your function or method is exported
4. Keep your errors unexported if they are only returned by unexported functions
5. Use `errors.Is(err, ErrExportedError)` to change behavior based on where the error is from.
