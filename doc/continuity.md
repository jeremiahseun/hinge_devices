# App continuity on foldables

When a Flip-class device is opened, Android moves your app from the cover
display to the inner one. When a Fold-class device is opened, the window
changes size dramatically. Both are **configuration changes**, and how your app
survives them is decided by your manifest — not by this package.

This is worth being blunt about: there is no "continuity API". Vendor
documentation that talks about app continuity is describing configuration and
OS behaviour. `hinge_devices` tells you what posture you are in; keeping
your state across the transition is your manifest's job.

## The three settings that matter

```xml
<application
    android:resizeableActivity="true">

    <activity
        android:name=".MainActivity"
        android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation|keyboardHidden|density"
        android:launchMode="singleTop">
        ...
    </activity>
</application>
```

**`android:resizeableActivity="true"`** — without it the system letterboxes your
app instead of handing it the new display. Required for continuity to happen at
all.

**`android:configChanges`** — the flags that matter for foldables are
`screenSize`, `smallestScreenSize`, `screenLayout` and `density`. Declaring them
means your Activity is *reconfigured* rather than destroyed and recreated, so
Dart state, scroll position and in-flight work survive the fold. Flutter's
default template already declares most of these; `density` is the one usually
missing, and it matters on Flip-class devices where the two displays have
different densities.

**`android:launchMode="singleTop"`** — prevents a second instance being created
on the new display.

## Check your manifest

```bash
dart run hinge_devices:check_manifest
```

Or from this repo:

```bash
dart run hinge_devices:check_manifest path/to/AndroidManifest.xml
```

## What still gets destroyed

Even with all three settings, the process can be killed under memory pressure
during the transition. Treat continuity as a fast path, not a guarantee —
persist anything the user would be upset to lose, exactly as you would across
any process death.

## Why posture can lag by a frame

The Activity is reattached before the hinge sensor's next reading arrives, so
the first state after an unfold is built from the folding feature alone. That
is deliberate: the folding feature is trustworthy immediately, and a hinge
reading held across an unregister is stale. See `PostureResolver.resolve` —
a reported folding feature always outranks a low angle.
