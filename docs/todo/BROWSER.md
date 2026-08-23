# GTK4 browser TODOs
- [ ] Make keyboard input work again. (**NOTE**: I believe the GTK4 shell itself should translate keycodes to web key names instead of delegating that responsibility to the WebView renderer)
- [ ] Tabbed browsing. I think most of the plumbing for it is already present.
- [ ] UI improvements
  * [ ] New Tab button
  * [ ] Close Tab button
  * [ ] Possibly using Adwaita's special tab overview widget (or whatever it is), like Epiphany?
- [ ] Stability
  * [ ] Attempt to restart Renderer if it crashes, but if it crashes again, don't try it again.
- [ ] Debugging
  * [ ] Add a Inspect-Element like menu where you can atleast see JS logs and stuff, possibly even the JS runtimes' state and stuff.
  * [ ] A few buttons and bells and whistles to do stuff like triggering garbage collection, showing layout bounds, etc.
