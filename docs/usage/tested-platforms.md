# Tested platforms

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

**InkProf has been tested on macOS. The application and its workflow have not been tested on Windows or Linux.**

MATLAB and Python are available for macOS, Windows and Linux. Their availability does not establish InkProf compatibility or validation on those platforms. ArgyllCMS, instrument communication, drivers, file paths and dialogs must also work together and be tested in each environment.

The interactive measurement bridge uses POSIX features. Linux remains untested even where the implementation targets POSIX systems. Windows instrument measurement additionally requires an adapted console transport and instrument testing.

Windows or Linux command examples in the documentation do not imply that InkProf has been tested there. Testing on macOS does not mean that every macOS version or instrument model has been verified.
