# QA Checklist for Manual Testing on Low-End Devices

## Device Requirements
- [ ] Android 8+ with 2GB RAM
- [ ] Test on 2G/3G network
- [ ] Test with battery saver enabled
- [ ] Test with low storage

## Core Features
- [ ] Splash and language picker
- [ ] Phone entry → OTP → profile setup (<30s to send first message)
- [ ] Send/receive messages on poor network
- [ ] Offline send queues and delivers on reconnect
- [ ] Voice notes (hold-to-record, slide-to-cancel)
- [ ] Voice/video calls
- [ ] Search messages
- [ ] Wallet top-up/send/receive
- [ ] Red packets
- [ ] Moments feed
- [ ] Channels player
- [ ] Mini programs

## Performance
- [ ] Cold start < 2.5s
- [ ] APK/AAB < 30MB
- [ ] Smooth scrolling at 60fps
- [ ] Memory < 250MB
- [ ] Battery usage acceptable
