extensions [matrix]

patches-own [
  p-type
  zone
  
  p-sus
  p-inf
  p-rec
  
  p-marked-for-contact
]

globals [
  land
  lake
  dead-space
  
  cold-dry
  hot-dry
  rainy
  transition
  
  cold-dry-months
  hot-dry-months
  rainy-months
  
  starting-month
  month-list
  old-season
  old-month
  current-season
  current-month
  
  ;initial-mobile-herds
  infection-start-time
  infection-start-herd
  infection-start-location
    
  regions
  
  movement-patterns ;a matrix that stores the regions and durations for each orbit. row 1 = regions, row 2 = how many weeks in each region, row 3 = how many weeks traveling between regions
  
  ;slider variables on front end
  ;mobile-transmission-rate ;; probability of infecting a herd within your range. range is proportional to herd size.
  ;infection-clear-time
  epi-start-locations
  this-seed
  
  all-herds  
  
  ext
  
  ;;track SIR levels for each run in a master matrix
  current-trial
  total-ticks
  
  S-data
  I-data
  R-data
  mobile-S
  mobile-I
  mobile-R
  contactable
  
  master-S
  master-I
  master-R
  master-mobile-S
  master-mobile-I
  master-mobile-R
  master-contactable
  mobile-list
  
  inf-threshold
  
  new-map
  new-height  
]

breed [drawing-turtles drawing-turtle]
breed [mobile-herds mobile-herd]
breed [sedentary-herds sedentary-herd]

mobile-herds-own [
  trajectory
  transmission-rate
  
  move-state
  orbit-index
  time-in-zone
  time-grazing
  time-cap
  destination
  orig-distance
   
  sus
  inf
  rec
  
  my-orbit
  marked-for-contact
]

to setup
  clear-all
  resize-world 0 79 0 89
  set-patch-size 10

  setup-patches
  setup-sedentary-herds
  
  ask patches with [any? sedentary-herds-here] [set p-type 0]
  set land patches with [p-type = 0]
  set dead-space patches with [p-type = 1]
  set lake patches with [p-type = 2]
  
  ;print-map-to-file
    
  ask dead-space [set pcolor black]
  ask land [set pcolor white]
  
  ask land [
    if ((pxcor mod 2) = 1 and (pycor mod 2 = 1)) or ((pxcor mod 2) = 0 and (pycor mod 2 = 0)) [set pcolor gray + 4]
  ]
  
  ;; all movement patterns are described starting in june  
  let orbit1 matrix:from-row-list [[8 1 4] [10 7 21] [5 1 8]]
  let orbit2 matrix:from-row-list [[8 1 3] [11 10 14] [7 2 8]]
  let orbit3 matrix:from-row-list [[7 4 3] [13 4 21] [3 1 10]]
  let orbit4 matrix:from-row-list [[6 1 5 3] [9 5 6 8] [7 3 2 12]]
  let orbit5 matrix:from-row-list [[6 1 5 3 9] [8 2 13 6 3] [9 1 4 3 3]]
  let orbit6 matrix:from-row-list [[6 1 4] [10 7 20] [7 1 7]]
  let orbit7 matrix:from-row-list [[6 1 3 9] [7 11 16 4] [4 1 3 6]]
  let orbit8 matrix:from-row-list [[6 0 1 3] [9 3 5 19] [6 2 2 6]] 
  
  set movement-patterns (list orbit1 orbit2 orbit3 orbit4 orbit5 orbit6 orbit7 orbit8)
  
  set month-list [ "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec" ]
  set starting-month "Jun"
  
  set cold-dry-months   map [? - 1] [1 10 11 12]
  set hot-dry-months    map [? - 1] [2 3 4 5]
  set rainy-months      map [? - 1] [6 7 8 9]
  
  set total-ticks 156
    
  set inf-threshold 0
      
  set infection-start-time 0
  set infection-start-location 43.16
      
  ;some acceptable start locations: [43 16] [47 2] [52 36] [31 22] 
  trial-setup
end

to trial-setup
  set this-seed new-seed
  random-seed this-seed
  
  set master-S [ ]
  set master-I [ ]
  set master-R [ ]
  set master-contactable [ ]
  set master-mobile-S [ ]
  set master-mobile-I [ ]
  set master-mobile-R [ ]
  
  set S-data matrix:make-constant world-width world-height 0
  set I-data matrix:make-constant world-width world-height 0
  set R-data matrix:make-constant world-width world-height 0
  set contactable matrix:make-constant world-width world-height 0
  
  initialize-patch-SIR
  
  set mobile-S matrix:make-constant initial-mobile-herds 5 0
  set mobile-I matrix:make-constant initial-mobile-herds 5 0
  set mobile-R matrix:make-constant initial-mobile-herds 5 0
 
  setup-mobile-herds
  
  set all-herds turtles with [breed = mobile-herds or breed = sedentary-herds]
  
  set current-month starting-month

  color-patch-based
  
  reset-ticks

  set-month-and-season
end

to go    
  save-SIR-data
  ;reality-check ;should print out a constant sum of 19081 * 30 = 572430 (total number of animals should be conserved at each tick)
  
  if (ticks = infection-start-time) [ start-infection ]
  
  if (save-movie?) [
    set ext (word "00" ticks)
    if (ticks >= 10 and ticks <= 99) [set ext (word "0" ticks) ]
    if (ticks > 99) [set ext ticks]
    export-interface (word "video" ext ".png")
  ]
  
  set-month-and-season
 
  move-mobile-herds 
  
  patch-disease-transmission
  color-patch-based
  
  tick
end

to move-mobile-herds  
  ask mobile-herds [
    if (time-in-zone = time-cap) [
      ifelse move-state = "in-zone" 
      [ set time-cap matrix:get trajectory 2 orbit-index
        set move-state "transitioning"
        set time-grazing 0
        set time-in-zone 0
        set destination one-of item (matrix:get trajectory 0 ((orbit-index + 1) mod (item 1 matrix:dimensions trajectory))) regions
        set orig-distance distance destination
      ]
      [ set orbit-index ((orbit-index + 1) mod (item 1 matrix:dimensions trajectory))
        set time-cap matrix:get trajectory 1 orbit-index
        set move-state "in-zone"
        set time-grazing 0
        set time-in-zone 0 ]
    ]
    
    if move-state = "in-zone"       [ in-zone-movement    ]
    if move-state = "transitioning" [ transition-movement ]  
    
    set time-in-zone (time-in-zone + 1)
  ]
end

to in-zone-movement
  let my-region matrix:get trajectory 0 orbit-index
  ifelse (time-grazing < 3)
  [ set time-grazing (time-grazing + 1) ]
  [ move-to one-of item my-region regions
    set time-grazing 0 ]
end

to transition-movement
   face destination
   forward (orig-distance / time-cap)
end

to patch-disease-transmission
  let B mobile-transmission-rate
  let G 1 / infection-clear-time
  let D 1 / immune-time

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ask land with [p-inf > inf-threshold] [
    matrix:set contactable pxcor pycor precision p-sus 4 ;any patch with infected cattle gets stored
    ask neighbors [ matrix:set contactable pxcor pycor precision p-sus 4] ;neighbors of any infected patches get stored as being contactable
  ]
  
  set master-contactable lput matrix:to-row-list contactable master-contactable
    
;  ask land         [set p-marked-for-contact 0]  
;  ask mobile-herds [set marked-for-contact 0]
;  
;  let mob-to-ask  mobile-herds with [inf > inf-threshold]
;  let land-to-ask land with [p-inf > inf-threshold]
;  
;  if (inf-threshold > 0) [
;    set mob-to-ask  mobile-herds with [inf >= inf-threshold]
;    set land-to-ask land with [p-inf >= inf-threshold]
;  ]
;  
;  ;; ask mobile-herds and patches to do their loops separately, since you can't combine patches and turtles in an agentset.
;  ask mob-to-ask [
;    ask land with [member? myself neighbors and not member? myself neighbors4] [ set p-marked-for-contact (p-marked-for-contact + 0.5) ]
;    ask neighbors4     [ set p-marked-for-contact (p-marked-for-contact + 1)   ]
;    ask mobile-herds in-radius 1.49 [ set marked-for-contact (marked-for-contact + 1) ]
;  ]
;  
;  ;determine the susceptibles that are in danger of getting infected (with inf threshold at 0)
;  ask land-to-ask [
;    ask land with [member? myself neighbors and not member? myself neighbors4] [ set p-marked-for-contact (p-marked-for-contact + 0.5) ]
;    ask neighbors4     [ set p-marked-for-contact (p-marked-for-contact + 1)   ]
;    ask mobile-herds in-radius 1.49 [ set marked-for-contact (marked-for-contact + 1) ]
;  ]
;  
;  ask land [ matrix:set contactable pxcor pycor (p-sus + (sum [sus] of mobile-herds-here)) ] 
  

    
  ;set contact-function replace-item ticks contact-function (sum [sus] of mobile-herds with [marked-for-contact > 0] + sum [p-sus] of land with [p-marked-for-contact >= 1] + 0.5 * sum [p-sus] of land with [p-marked-for-contact = 0.5])
  ;matrix:set contact-function current-trial ticks (sum [sus] of mobile-herds with [marked-for-contact > 0] + sum [p-sus] of land with [p-marked-for-contact >= 1] + 0.5 * sum [p-sus] of land with [p-marked-for-contact = 0.5])
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  
    
  ask mobile-herds [
    let diag-neighbors land with [member? myself neighbors and not member? myself neighbors4]
    let all-inf (sum [p-inf] of neighbors4 + 0.5 * sum [p-inf] of diag-neighbors + sum [inf] of mobile-herds in-radius 1.49)
    
    let new-sus 0
    let new-inf 0
    let new-rec 0
    
    if (dependence = "density") [
      set new-sus (sus + D * rec - B * all-inf * sus)
      set new-inf (inf - G * inf + B * all-inf * sus)
      set new-rec (rec + G * inf - D * rec)
    ]
    
    if (dependence = "frequency") [
      let all-sus (sum [p-sus] of neighbors4 + 0.5 * sum [p-sus] of diag-neighbors + sum [sus] of mobile-herds in-radius 1.49)      
      let all-rec (sum [p-rec] of neighbors4 + 0.5 * sum [p-rec] of diag-neighbors + sum [rec] of mobile-herds in-radius 1.49)
      set new-sus (sus + D * rec - B * all-inf * sus / (all-sus + all-inf + all-rec))
      set new-inf (inf - G * inf + B * all-inf * sus / (all-sus + all-inf + all-rec))
      set new-rec (rec + G * inf - D * rec)
    ]
    
    set sus new-sus
    set inf new-inf
    set rec new-rec
  ]
      
  ask land with [any? sedentary-herds-here] [
    let diag-neighbors land with [member? myself neighbors and not member? myself neighbors4]
    let all-inf (p-inf + sum [p-inf] of neighbors4 + 0.5 * sum [p-inf] of diag-neighbors + sum [inf] of mobile-herds in-radius 1.49)
        
    let new-sus 0
    let new-inf 0
    let new-rec 0
    
    if (dependence = "density") [
      set new-sus (p-sus + D * p-rec - B * all-inf * p-sus)
      set new-inf (p-inf - G * p-inf + B * all-inf * p-sus)
      set new-rec (p-rec + G * p-inf - D * p-rec)
    ]
    
    if (dependence = "frequency") [
      let all-sus (p-sus + sum [p-sus] of neighbors4 + 0.5 * sum [p-sus] of diag-neighbors + sum [sus] of mobile-herds in-radius 1.49)
      let all-rec (p-rec + sum [p-rec] of neighbors4 + 0.5 * sum [p-rec] of diag-neighbors + sum [rec] of mobile-herds in-radius 1.49)
      set new-sus (p-sus + D * p-rec - B * all-inf * p-sus / (all-sus + all-inf + all-rec))
      set new-inf (p-inf - G * p-inf + B * all-inf * p-sus / (all-sus + all-inf + all-rec))
      set new-rec (p-rec + G * p-inf - D * p-rec)
    ]
    
    set p-sus new-sus
    set p-inf new-inf
    set p-rec new-rec
  ]
    
  if any? mobile-herds with [sus > 30] [ print "problem!"] ;prints out a warning flag if dynamics are weird
end

to setup-mobile-herds
  ask mobile-herds [die]
  if (orbit-to-include != 0) [
    create-mobile-herds (initial-mobile-herds) [
      set shape "cow"
      set size 0.9 ;random-normal 1.5 0.4
      set color green
    
      set sus 30
      set inf 0
      set rec 0
      
      ;; this code uses orbit distributions from data, but for now i keep it uniform so that the effect of each can be compared directly
      ;    let r random 67
      ;    if (r < 8)              [set trajectory item 0 movement-patterns]
      ;    if (r >= 8 and r < 14)  [set trajectory item 1 movement-patterns]
      ;    if (r >= 14 and r < 18) [set trajectory item 2 movement-patterns]
      ;    if (r >= 18 and r < 25) [set trajectory item 3 movement-patterns]
      ;    if (r >= 25 and r < 31) [set trajectory item 4 movement-patterns]
      ;    if (r >= 31 and r < 43) [set trajectory item 5 movement-patterns]
      ;    if (r >= 43 and r < 44) [set trajectory item 6 movement-patterns]
      ;    if (r >= 44)            [set trajectory item 7 movement-patterns]
      set trajectory item (orbit-to-include - 1) movement-patterns
    
      set my-orbit position trajectory movement-patterns
      set mobile-list sort-on [my-orbit] mobile-herds
      foreach n-values length mobile-list [?] [
        ask item ? mobile-list [
          matrix:set mobile-S ? 0 who
          matrix:set mobile-S ? 1 my-orbit
          matrix:set mobile-I ? 0 who
          matrix:set mobile-I ? 1 my-orbit
          matrix:set mobile-R ? 0 who
          matrix:set mobile-R ? 1 my-orbit
        ]
      ]
       
      move-to one-of item (matrix:get trajectory 0 0) regions
      set move-state "in-zone"
      set time-in-zone 0
      set time-grazing 0
      set time-cap (matrix:get trajectory 1 0)
      set transmission-rate mobile-transmission-rate
    ]
  ]
end

to start-infection
  if (epidemic-start-location = "single") [
    let x-start int (infection-start-location * max-pxcor / 79)
    let y-start round ((100 * (infection-start-location mod int infection-start-location)) * max-pycor / 89)
  
    let start-patch patch x-start y-start
    ask start-patch [set pcolor yellow]
  
    ask start-patch [
      set pcolor red
      set p-sus (p-sus - 1)
      set p-inf (p-inf + 1)
    ]
  ]
  if (epidemic-start-location = "multiple") [
    let start-patches get-scaled-locations ([[44 74] [68 5] [40 22] [18 23]])
    ask start-patches [
      set pcolor red
      set p-sus (p-sus - 1)
      set p-inf (p-inf + 1)
    ]
  ]
  if (epidemic-start-location = "mobile") [
    set infection-start-herd one-of mobile-herds with [member? patch-here item 6 regions]
    ask infection-start-herd [
      print my-orbit
      set color red
      set size 2
      set sus (sus - 1)
      set inf (inf + 1)
    ]
  ]   
end

to-report get-scaled-locations [coords]
  let start-patches nobody
  foreach coords [set start-patches (patch-set start-patches patch (int (item 0 ? * max-pxcor / 79)) (int (item 1 ? * max-pycor / 89)))]
  report start-patches
end

to setup-sedentary-herds
  file-open "sedentary-locations.txt"
  let x-loc file-read
  let y-loc file-read
  file-close
  
  (foreach x-loc y-loc [
    create-sedentary-herds 1 [
      set shape "dot"      
      set size 0.4 * width / 80
      set color blue
      ;print ?2
      setxy (?1 * max-pxcor / 80) (?2 * max-pycor / 90)
    ]
  ])
  
  set-original-zones
end
  
to color-patch-based
  ask land [ set pcolor scale-color red p-inf 150 0 ]
end

to set-month-and-season
  set old-season current-season
  set old-month current-month

  let t-index ticks mod 52
  
  if (t-index < 17)  [ set current-season "rainy" ]
  if (t-index >= 17 and t-index < 35) [ set current-season "cold-dry"]
  if (t-index >= 35) [ set current-season "hot-dry"]
 
  if (t-index < 4)                    [ set current-month "Jun" ]
  if (t-index >= 4 and t-index < 8)   [ set current-month "Jul" ]
  if (t-index >= 8 and t-index < 12)  [ set current-month "Aug" ]
  if (t-index >= 12 and t-index < 17) [ set current-month "Sep" ]
  if (t-index >= 17 and t-index < 22) [ set current-month "Oct" ]
  if (t-index >= 22 and t-index < 26) [ set current-month "Nov" ]
  if (t-index >= 26 and t-index < 30) [ set current-month "Dec" ]
  if (t-index >= 30 and t-index < 35) [ set current-month "Jan" ]
  if (t-index >= 35 and t-index < 39) [ set current-month "Feb" ]
  if (t-index >= 39 and t-index < 44) [ set current-month "Mar" ]
  if (t-index >= 44 and t-index < 48) [ set current-month "Apr" ]
  if (t-index >= 48)                  [ set current-month "May" ] 
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Visualization setup code ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-patches
  file-open "map80.txt"
  let map-matrix file-read
  file-close
  resize-world 0 ((length item 0 map-matrix) - 1) 0 ((length map-matrix) - 1)
  set map-matrix matrix:from-row-list map-matrix
  print world-width
  print world-height
 
  let x 0
  let y 0
  while [y < world-height] [
    set x 0
    while [x < world-width] [
      ask patch x y [set p-type matrix:get map-matrix y x]
      set x x + 1
    ]
    set y y + 1
  ]
  
  set new-height ceiling (9 * width / 8)
  set new-map matrix:make-constant (width) new-height 0
  let x-space 80 / (width + 1)
  let y-space 89 / (new-height + 1)
  
  let i 0
  let j 0
  while [j < new-height] [
    set i 0
    while [i < width] [
      matrix:set new-map i j ([p-type] of patch ((1 + i) * x-space) ((1 + j) * y-space))
      set i (i + 1)
    ]
    set j (j + 1)
  ]
  
  resize-world 0 (width - 1) 0 (new-height - 1)
  set-patch-size 640 / width
  set y 0
  while [y <= max-pycor] [
    set x 0
    while [x <= max-pxcor] [
      ask patch x y [set p-type matrix:get new-map x y]
      set x x + 1
    ]
    set y y + 1
  ]
  
  ;pmat new-map
end

to initialize-patch-SIR
  ask land [
    set p-sus (30 * count sedentary-herds-here)
    set p-inf 0
    set p-rec 0
  ]
end

to save-SIR-data
  ask land [
    matrix:set S-data pxcor pycor precision (p-sus) 3
    matrix:set I-data pxcor pycor precision (p-inf) 3
    matrix:set R-data pxcor pycor precision (p-rec) 3
  ]
  
  set master-S lput matrix:to-row-list S-data master-S
  set master-I lput matrix:to-row-list I-data master-I
  set master-R lput matrix:to-row-list R-data master-R
  
  if (any? mobile-herds) [
    foreach n-values length mobile-list [?] [
      ask item ? mobile-list [
        matrix:set mobile-S ? 2 (precision sus 3) matrix:set mobile-S ? 3 pxcor matrix:set mobile-S ? 4 pycor
        matrix:set mobile-I ? 2 (precision inf 3) matrix:set mobile-I ? 3 pxcor matrix:set mobile-I ? 4 pycor
        matrix:set mobile-R ? 2 (precision rec 3) matrix:set mobile-R ? 3 pxcor matrix:set mobile-R ? 4 pycor
      ]
    ]
  ]
  ;set master-mobile-S lput matrix:to-row-list mobile-S master-mobile-S
  ;set master-mobile-I lput matrix:to-row-list mobile-I master-mobile-I
  ;set master-mobile-R lput matrix:to-row-list mobile-R master-mobile-R
end

to-report scale-zone-edges [corner-list]
  report map [? * max-pxcor / 79] corner-list
end

to set-original-zones
  set cold-dry [ ]
  set hot-dry [ ]
  set rainy [ ]
  set transition [ ]
    
  let edges [ ]
  
  ;; zones are defined according to the original map, then used for re-scaling later.
  ;; this maintains more integrity for the zones when scaling to large cells, but it does have the effect of enlarging some of the zones.
  foreach [[52 58 19 23] [45 64 34 52] [56 60 56 60]] [
    set edges scale-zone-edges ?
    set cold-dry lput (patches with [pxcor >= floor (item 0 edges) and pxcor <= ceiling (item 1 edges) and pycor >= floor (item 2 edges) and pycor <= ceiling (item 3 edges) and p-type != 1]) cold-dry
    draw-box floor (item 0 edges) ceiling (item 1 edges) floor (item 2 edges) ceiling (item 3 edges) (blue - 1)
  ]

  foreach [[51 63 16 35] [51 62 37 52] [55 61 53 68]] [
    set edges scale-zone-edges ?
    set hot-dry lput (patches with [pxcor >= floor (item 0 edges) and pxcor <= ceiling (item 1 edges) and pycor >= floor (item 2 edges) and pycor <= ceiling (item 3 edges) and p-type != 1] ) hot-dry
    draw-box floor (item 0 edges) ceiling (item 1 edges) floor (item 2 edges) ceiling (item 3 edges) (red)
  ]

  foreach [[28 48 6 19] [39 42 25 29] [29 36 34 38]] [
    set edges scale-zone-edges ?
    set rainy lput (patches with [pxcor >= floor (item 0 edges) and pxcor <= ceiling (item 1 edges) and pycor >= floor (item 2 edges) and pycor <= ceiling (item 3 edges) and p-type != 1] ) rainy
    draw-box floor (item 0 edges) ceiling (item 1 edges) floor (item 2 edges) ceiling (item 3 edges) (green - 1)
  ]

  set edges scale-zone-edges [59 63 10 13]
  set transition lput (patches with [pxcor >= floor (item 0 edges) and pxcor <= ceiling (item 1 edges) and pycor >= floor (item 2 edges) and pycor <= ceiling (item 3 edges) and p-type != 1] ) transition
  draw-box floor (item 0 edges) ceiling (item 1 edges) floor (item 2 edges) ceiling (item 3 edges) (yellow - 2)

  ask patches [set zone ["none"]]
  
  ask patch-set cold-dry   [set zone ["cold-dry"] ]
  ask patch-set hot-dry    [set zone ["hot-dry"] ]
  ask patch-set rainy      [set zone ["rainy"] ]
  ask patch-set transition [set zone ["transition"] ]
  
  ask patches with [member? self patch-set cold-dry and member? self patch-set hot-dry] [set zone ["cold-dry" "hot-dry"] ]
  
  set regions reduce sentence (list cold-dry hot-dry rainy transition)
end 
  
to draw-box [x1 x2 y1 y2 col]
  let scale 0.5
  create-drawing-turtles 1 [
    set color col
    setxy (x1 - scale) (y1 - scale) pen-down
    setxy (x2 + scale) (y1 - scale)
    setxy (x2 + scale) (y2 + scale)
    setxy (x1 - scale) (y2 + scale)
    setxy (x1 - scale) (y1 - scale)
    die
  ]
end

to create-legend
  ask patches with [pxcor <= 21 and pycor >= 71] [set pcolor black]
  
  create-drawing-turtles 1 [
    set size 1
    set color black
    move-to patch 20 85 
    set label-color blue
    set label "Cold dry"
  ]
  create-drawing-turtles 1 [
    set size 1
    set color black
    move-to patch 20 81 
    set label-color red
    set label "Hot dry"
  ]
  create-drawing-turtles 1 [
    set size 1
    set color black
    move-to patch 20 77 
    set label-color green
    set label "Rainy"
  ]
  create-drawing-turtles 1 [
    set size 1
    set color black
    move-to patch 20 73 
    set label-color yellow
    set label "Transition"
  ]
  create-drawing-turtles 1 [
    set size 1
    set color black
    move-to patch 76 31
    set label-color white
    set label "Maga"
  ]
end
 
to reality-check
  print (matrix:get master-S current-trial ticks) + (matrix:get master-I current-trial ticks) + (matrix:get master-R current-trial ticks)
end

;to write-data-to-file
;  let filename (word "data" position current-start-location epi-start-locations ".csv")
;  
;  ;let filename (word "R" FMD-start-region "-" initial-mobile-herds "-" inf-threshold  "-" trials "trials.csv")
;  if (file-exists? filename) [file-delete filename]
;  
;  file-open filename
;  file-print "S (mean), S (stdev), I (mean), I (stdev), R (mean), R (stdev), Contact (mean), Contact (stdev)"
;  
;  let i 0
;  while [i < 52 * sim-years] [
;    file-type (word mean (matrix:get-column master-S i) ",")
;    file-type (word standard-deviation (matrix:get-column master-S i) ",")
;    file-type (word mean (matrix:get-column master-I i) ",")
;    file-type (word standard-deviation (matrix:get-column master-I i) ",")
;    file-type (word mean (matrix:get-column master-R i) ",")
;    file-type (word standard-deviation (matrix:get-column master-R i) ",")
;    file-type (word mean (matrix:get-column contact-function i) ",")
;    file-type (word standard-deviation (matrix:get-column contact-function i) ",")    
;    file-print " "
;    set i (i + 1)  
;  ]
;  
;  file-close
;end
  
to write-run-data
  print length master-S
  print length master-I
  print length master-R
  
  
  let filename "f"
  if (epidemic-start-location = "single")   [set filename (word "size" width "-data-4316-orbit" orbit-to-include "-Run" int (behaviorspace-run-number mod 50) ".csv")]
  if (epidemic-start-location = "multiple") [set filename (word "size" width "-data-multiple-orbit" orbit-to-include "-Run" int (behaviorspace-run-number mod 50) ".csv")]
  if (epidemic-start-location = "mobile")   [set filename (word "size" width "-data-mobile-orbit" orbit-to-include "-Run" int (behaviorspace-run-number mod 50) ".csv")]
  if (file-exists? filename) [file-delete filename]
  file-open filename  
    
  file-print "tick, S, I, R" ; , contact, mobS, mobI, mobR"
  let i 0
  while [i < total-ticks] [
    file-type (word i ",")
    file-type (word item i master-S ",")
    file-type (word item i master-I ",")    
    file-type (word item i master-R ",")
    ;file-type (word item i master-contactable ",")
    ;file-type (word item i master-mobile-S ",")
    ;file-type (word item i master-mobile-I ",")
    ;file-type (word item i master-mobile-R ",")        
    file-print " "
    set i (i + 1)
  ]
  
  ;;write various variables about the run here
  file-print " "
  if (epidemic-start-location = "single")   [file-print (word "Start location," int infection-start-location "," round (100 * (infection-start-location mod int infection-start-location)))]
  if (epidemic-start-location = "multiple") [file-print (word "Start location," epidemic-start-location ", [(44,74) (68,5) (40,22) (18,23)]")]
  if (epidemic-start-location = "mobile")   [file-print (word "Start location," epidemic-start-location ", orbit " [my-orbit] of infection-start-herd)]
  file-print (word "Mobile transmission rate," mobile-transmission-rate)
  file-print (word "Inf. clear time," infection-clear-time)
  file-print (word "Immune time," immune-time)
  file-print (word "Mobile herds," initial-mobile-herds)
  file-print (word "Seed," this-seed)
    
  file-close
end

to write-run-data2
  let filename "f"
  if (epidemic-start-location = "single")   [set filename (word "size" width "-data-4316-orbit" orbit-to-include "-")]
  if (epidemic-start-location = "multiple") [set filename (word "size" width "-data-multiple-orbit" orbit-to-include "-")]
  
  let i 0
  while [i < total-ticks] [    
    file-open (word "Size " width "/" filename "S-" i ".txt")
    file-print item i master-S
    file-close
    
    file-open (word "Size " width "/" filename "I-" i ".txt")
    file-print item i master-I
    file-close
    
    file-open (word "Size " width "/" filename "R-" i ".txt")
    file-print item i master-R
    file-close
    
    set i (i + 1)
  ]
end

to-report read-data-test
  file-open "test-I-data.txt"
  let t-data file-read 
  file-close
  report t-data
end

to pmat [mat]
  print matrix:pretty-print-text mat
end

to print-map-to-file
  let x 0
  let y 0
  let final-map matrix:make-constant world-width world-height 0
  
  while [y <= max-pycor] [
    set x 0
    while [x <= max-pxcor] [
      matrix:set final-map x y ([p-type] of patch x y)
      set x (x + 1)
    ]
    set y (y + 1)
  ]
  
  ;pmat final-map
  
  ; used to generate map files for the region definer
  let file-to-print (word "map" width ".txt")
  if (file-exists? file-to-print) [file-delete file-to-print]
  file-open file-to-print
  file-print matrix:to-column-list final-map
  file-close
end
  
@#$#@#$#@
GRAPHICS-WINDOW
212
10
756
644
-1
-1
6.4
1
35
1
1
1
0
0
0
1
0
99
0
112
1
1
1
ticks
30.0

BUTTON
9
11
75
44
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
9
54
66
99
Month
current-month
17
1
11

MONITOR
78
55
155
100
Season
current-season
17
1
11

SLIDER
9
107
201
140
mobile-transmission-rate
mobile-transmission-rate
0.5
5
1
0.05
1
NIL
HORIZONTAL

SLIDER
10
146
202
179
infection-clear-time
infection-clear-time
1
12
4
1
1
NIL
HORIZONTAL

SLIDER
10
185
202
218
immune-time
immune-time
0
96
52
1
1
NIL
HORIZONTAL

SWITCH
10
225
144
258
save-movie?
save-movie?
1
1
-1000

MONITOR
10
366
167
411
max inf
max [inf] of mobile-herds
17
1
11

MONITOR
10
314
167
359
max sus
max [sus] of mobile-herds
17
1
11

CHOOSER
10
264
148
309
dependence
dependence
"density" "frequency"
1

MONITOR
10
416
67
461
Trial
current-trial
17
1
11

INPUTBOX
9
480
127
540
initial-mobile-herds
25
1
0
Number

INPUTBOX
70
416
139
476
sim-years
3
1
0
Number

INPUTBOX
9
545
120
605
orbit-to-include
0
1
0
Number

INPUTBOX
10
612
142
672
epidemic-start-location
multiple
1
0
String

CHOOSER
10
679
148
724
width
width
100 80 60 40 20 10
0

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

start-cow
false
0
Polygon -7500403 true true 200 208 197 264 179 264 177 211 166 202 140 204 93 206 78 194 72 226 49 224 48 196 37 164 25 135 25 104 45 87 103 99 179 90 198 91 252 79 272 96 293 118 285 136 255 136 242 133 224 182
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123
Circle -7500403 false true 2 2 297

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Remaining multiple runs" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>write-run-data2</final>
    <timeLimit steps="156"/>
    <enumeratedValueSet variable="width">
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epidemic-start-location">
      <value value="&quot;multiple&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orbit-to-include">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-mobile-herds">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobile-transmission-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sim-years">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-clear-time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dependence">
      <value value="&quot;frequency&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="save-movie?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immune-time">
      <value value="52"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="EffectOfOrbits" repetitions="13" runMetricsEveryStep="false">
    <setup>trial-setup</setup>
    <go>go</go>
    <final>write-run-data</final>
    <timeLimit steps="52"/>
    <enumeratedValueSet variable="epidemic-start-location">
      <value value="&quot;single&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orbit-to-leave-out">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-mobile-herds">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobile-transmission-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sim-years">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-clear-time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dependence">
      <value value="&quot;frequency&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="save-movie?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immune-time">
      <value value="52"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="EffectOfOrbits" repetitions="30" runMetricsEveryStep="false">
    <setup>trial-setup</setup>
    <go>go</go>
    <final>write-run-data</final>
    <timeLimit steps="104"/>
    <enumeratedValueSet variable="epidemic-start-location">
      <value value="&quot;multiple&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orbit-to-include">
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-mobile-herds">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobile-transmission-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sim-years">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-clear-time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dependence">
      <value value="&quot;frequency&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="save-movie?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immune-time">
      <value value="52"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="EffectOfScale2" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>write-run-data2</final>
    <timeLimit steps="156"/>
    <enumeratedValueSet variable="width">
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epidemic-start-location">
      <value value="&quot;single&quot;"/>
      <value value="&quot;multiple&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orbit-to-include">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-mobile-herds">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobile-transmission-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sim-years">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-clear-time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dependence">
      <value value="&quot;frequency&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="save-movie?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immune-time">
      <value value="52"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
