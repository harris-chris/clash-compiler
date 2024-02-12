import Clash.Prelude
import Clash.Annotations.TH
topEntity
    :: "BTN" ::: Signal System Bit
    -> "LED" ::: Signal System Bit
topEntity = id
makeTopEntity 'topEntity
