# Rule 90 Sonification

Dieser Code sonfiziert einen 1D cellular automata, basierend auf Rule 90. Die
Ausgangskonfiguration wird rein zufällig bestimmt und kann mittels Parameter
konfiguriert werden. Die aktiven Zellen der aktuellen Generation des CAs werden
als Note interpretiert (major scale) und abgespielt. Pro Generation werden mehrere
Töne angespielt. Ein ADSR Envelop lässt die Noten sanft ausklingen. Um noch
mehr Variation einfließen zu lassen, wird auch die zeitliche Entwicklung be-
rücksichtig: die Summe der vergangenen aktiven Zellen (Wert "1") bestimmt die
Lautstärke und die "Raumgröße" (Reverb Filter). Tiefe Tonlagen deuten an, dass
aktive Zellen weiter links sind (Tonhöhe steigt nach rechts). Weitere Details
zur Synthese befinden sich in den Kommentaren im Code.

Für ein akkustisch spannenderes Ergebnis, wird noch ein kleiner Echo Effekt
angehängt (wird aber nicht weiter vom CA gesteuert). Dafür ist das "Feedback"
Quark notwendig. Die Installation kann über den Code ausgeführt werden, ggf.
ist das Paket auch im selben Ordner.
