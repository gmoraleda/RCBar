# RCBar

macOS menu bar app showing your next App Store payout (RevenueCat proceeds, Apple fiscal calendar).

    mkdir -p ~/.config/rcbar
    echo '{"apiKey":"sk_...","projectId":"proj...","currency":"EUR"}' > ~/.config/rcbar/config.json
    ./make-app.sh                         # builds ~/Applications/RCBar.app, launches it, adds login item
    swift run RCBar --selftest

`projectId` and `currency` are optional (first project / EUR). Needs a v2 secret key with metrics read access.
Fiscal dates are computed; Apple's calendar in App Store Connect is the source of truth.
