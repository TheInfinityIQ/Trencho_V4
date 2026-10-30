extends RefCounted
## GDD 13.5 proposed defaults. Devices are field actions consuming M06.
const TYPES := {
	"D01":{"m06":1,"work":8.0,"trigger":1.0,"radius":5.0,"injury":90,"damage":0,"penetration":5},
	"D02":{"m06":3,"work":12.0,"trigger":1.5,"radius":4.0,"injury":100,"damage":650,"penetration":160},
	"D03":{"m06":4,"work":20.0,"trigger":3.0,"radius":6.0,"injury":120,"damage":900,"penetration":180},
}
