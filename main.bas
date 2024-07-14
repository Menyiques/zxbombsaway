'Thanks to: 
'DamienG:           font
'Duefectu:          Boriel Basic for ZX Spectrum: A guide for dummies…and those who are not so much.
'José Rodriguez:    Boriel:        
'David Saphier:     NextBuild
'Tomaˇz Kragelj:    ZX Spectrum Next Assembly Developer Guide
'Javi Ortiz:        
'ZXArt:             bso 
'
'!ORG=26000
'!HEAP=2048
#define IM2
#define NEX

declare function getkey(k1 as string,k2 as string,k3 as string) as string
declare function cap(a$ as string) as string

#include <nextlib.bas>
#include <print42.bas>

poke uinteger 23606, @font-256

NextReg($7,$3)  		' go 28mhz 
NextReg($70,%00010000)  '00=Reserved-100=320x256xx8-000=Palette offset
'Clip window 320x256
NextReg($18,0)
NextReg($18,159)
NextReg($18,0)
NextReg($18,255)

LoadSDBank("vt24000.bin",0,0,0,35)
LoadSDBank("bombs.afb",0,0,0,36) 	
LoadSDBank("bomb.pt3",0,0,0,37) 	
LoadSDBank("gameover.pt3",0,0,0,34)

SetUpIM()                                       ' init the IM2 code 
InitSFX(36)							            ' init the SFX engine, sfx are in bank 46							           
EnableSFX	

NextReg($15,%00010100)  	
'Bit    Effect
'----------------------------------------------'
'7      1 to enable lo-res layer, 0 disable it
'6      1 to flip sprite rendering priority, i.e. sprite 0 is on top (0 after reset)
'5      1 to change clipping to 'over border' mode (doubling X-axis coordinates of clip window, 0 after reset)
'4-2    Layers priority and mixing
'           000 S L U (Sprites are at top, Layer 2 under, Enhanced ULA at bottom)
'           001 L S U
'           010 S U L
'           011 L U S
'           100 U S L
'         * 101 U L S
'           110 Core 3.1.1+: (U|T)S(T|U)(B+L) blending layer and Layer 2 combined Older cores: S(U+L) colours from ULA and L2 added per R/G/B channel
'           111 Core 3.1.1+: (U|T)S(T|U)(B+L-5) blending layer and Layer 2 combined Older cores: S(U+L-5) similar as 110, but per R/G/B channel (U+L-5)
'           110 and 111 modes: colours are clamped to [0,7]
'1      1 to enable sprites over border (0 after reset)
'0      1 to enable sprite visibility (0 after reset)

NextReg($08,%11010010) 'Memory contention off'
    'bit 7 = Unlock(1)/lock(0) port $7FFD paging (read 1 indicates port $7FFD is not locked)
    'bit 6 = 1 to disable RAM and I/O port contention (soft reset = 0)
    'bit 5 = AY stereo mode (0 = ABC, 1 = ACB) (hard reset = 0)
    'bit 4 = Enable internal speaker (hard reset = 1)
    'bit 3 = Enable 8-bit DACs (A,B,C,D) (hard reset = 0)
    'bit 2 = Enable port $FF Timex video mode *read* (hides floating bus on 0xff) (hard reset = 0)
    'bit 1 = Enable Turbosound (currently selected AY is frozen when disabled) (hard reset = 0)
    'bit 0 = Implement Issue 2 keyboard (port $FE reads as early ZX boards) (hard reset = 0)
NextReg($9,%01000000) 'SFX AY chip (#2) mono'


'Layer 2 está en 10 páginas de 8kb verticales (de 32x256) desde la página 100 hasta la 109'

LoadSDBank("sprites.bin",0,0,0,38) ' En el 38 de 8Kb (26h)


dim x,y as uinteger
dim tea(4,1) as uinteger 'en la 0 está el estado (0 no hay, 1 arriba, 2 medio, 3 abajo), en la 1 los frames que le quedan para pasar al siguiente estado'
dim puro(1) as uinteger 'en la 0 está el estado (0 no hay, 1 arriba, 2 medio, 3 abajo, y luego las 5 llamas), en la 1 los frames que le quedan para pasar al siguiente estado'


poke @mode,$0 'pinta'

paper 3: bright 0:border 3: cls
NextReg($14,162) 'color magenta brillo0




dim spxy (59,1) as uinteger =>{{0,93}    , {31,116}  , {35,86}   , {46,132}  , {35,145}  , {0,0}     , {10,196}  , {31,182}  , {23,139}  , {0,148}   ,_
                               {59,169}  , {82,146}  , {82,194}  , {103,166} , {124,149} , {124,195} , {144,169} , {167,150} , {168,196} , {187,168} ,_ 
                               {209,150} , {210,196} , {229,167} , {250,153} , {252,194} , {64,128}  , {68,100}  , {86,92}   , {84,110}  , {82,125}  ,_
                               {94,133}  , {283,142} , {270,122} , {299,106} , {282,101} , {305,62}  , {57,41}   , {254,42}  , {210,42}  , {166,42}  ,_
                               {122,42}  , {78,42}   , {283,183} , {302,176} , {276,172} , {274,205} , {273,225} , {55,0}    , {54,70}   , {0,30}    ,_
                               {87,227}  , {130,227} , {173,227} , {216,227} , {259,227} , {81,236}  , {50,7}    , {56,189}  , {50,184} ,  {250,153}}


dim misses as ubyte=0
dim points as uinteger=0
dim frames,oldframes as long 
dim mario_pos,mario_old_pos as ubyte
dim quarterback as ubyte =0
dim frames_quarterback as uinteger
dim iddlekey as ubyte
dim lastkey,kl,kr,kf as string
dim manos_arriba, manos_changed as ubyte
dim bombas_ok as ubyte
dim puntos as uinteger
dim tea_movida as ubyte
dim score_mode as ubyte
dim c_old(2) as ubyte


dim freq_qua_up, freq_qua_down,freq_tea,freq_puro as uinteger

kl="o"
kr="p"
kf=" "
setup_joystick()



menu:

InitMusic(35,37,0000)				            ' init the music engine 44 has the player, 45 the pt3, 0000 the offset in bank 45
EnableMusic

menukeylabel:

LoadSDBank("menu.bin",0,0,0,170)
NextReg($12,85)
showlayer2(1)
dim random as uinteger

do
    inkey_joy()
    random=random+1
loop until lastkey<>""

  if cap(lastkey)="H" or lastkey=kr   then pause0(): manual(): goto menukeylabel
  if cap(lastkey)="R" then redefine(): goto menukeylabel


randomize random

DisableMusic
showlayer2(0)
NextReg($12,50)'Layer 2 en el banco 50 de 16kb (seria el 100(64h) de 8Kb, 101,102,103,104,105,106 y 107)

start_game:
    for n=0 to 2
        c_old(n)=0
    next n
    
    frames=0
    oldframes=0

    puntos=0
    misses=0
    points=0
    bombas_ok=0

   freq_qua_up=216
   freq_qua_down=54
   freq_tea=56
   freq_puro=84

  
    for n=0 to 4
        tea(n,0)=0
        tea(n,1)= int(rnd*freq_tea)+freq_tea
    next n
  

start_life:
    if misses=3 
        playsfx(12)
        print at  9,12;paper 0;ink 4;"           "
        print at 10,12;paper 0;ink 4;bright 1;" GAME OVER "
        print at 11,12;paper 0;ink 4;"           "
        waitretrace(3000)
        InitMusic(35,34,0000)
        EnableMusic
        pause0()
        cls
        goto menu
    end if
    score_mode=1' mode 1=normal, mode 2= chance time

after_charly_explota:
    bombas_ok=0
    puro(0)=0
    puro(1)=50
    cls320x256(0)  

    pinta_misses()
    pinta_puntos(1)
    pinta_escenario()
    showlayer2(1)
    PlaySFX(0) 
    intro(300)
    pinta(0)

    for n=90 to 94:borra(n):next n
  
  
    waitretrace(400)

    for n=0 to 4
        pinta(80+n)
    next n

after_bomb:
    intro_first(200)
    mario_pos=0
    mario_old_pos=0
    manos_arriba=0
    manos_changed=0
    frames_quarterback=0
    quarterback=0

    if puro(0)=8 or puro(0)=7 then  puro(0)=0: borra(51): borra(50):puro(1)=100 'si hay llama de puro nada mas salir bórrala porque nos mataría 



do


if quarterback=0 and frames_quarterback>=freq_qua_up then
    borra(33)
    pinta(32)
    frames_quarterback=0
    quarterback=1
end if

if quarterback=1 and frames_quarterback>=freq_qua_down then
    borra(32)
    pinta(33)
    frames_quarterback=0
    quarterback=0
end if


'TEA'
tea_movida=0
for n=0 to 4
tea(n,1)=tea(n,1)-1


if tea(n,1)=0 
    if n=0 tea_movida=1
    'borra la antigua'
    if tea(n,0)=1 or tea(n,0)=5 borra(100+n)
    if tea(n,0)=2 or tea(n,0)=4 borra(110+n)
    if tea(n,0)=3 borra(120+n):borra(130+n)    
    tea(n,0)=tea(n,0)+1: if tea(n,0)=6 then tea(n,0)=0
    if tea(n,0)=3 then tea(n,1)=freq_tea*2 else tea(n,1)=freq_tea ' si el estado es 3 espera 100 frames, los demás 50 frames'
    if tea(n,0)=0 then tea(n,1)=int(rnd*6)*freq_tea+freq_tea
    'pinta la nueva'
    if tea(n,0)=1 or tea(n,0)=5 pinta(100+n)
    if tea(n,0)=2 or tea(n,0)=4 pinta(110+n)
    if tea(n,0)=3 pinta(120+n):pinta(130+n)    
end if

next n

if tea_movida=1 then PlaySFX(5)


'PURO'
puro(1)=puro(1)-1
if puro(1)=0
    if puro(0)<4
        borra(puro(0)+43)
    else
        borra(58-puro(0))
    end if
    if puro(0)=1 pinta(43)
    puro(0)=puro(0)+1
    if puro(0)=9 then
        puro(0)=0
    else
        if puro(0)<4
            pinta(puro(0)+43)
        else
            pinta(58-puro(0))
        end if
    end if
  
    puro(1)=freq_puro
end if




inkey_joy()


if lastkey<>kl and lastkey<>kr and lastkey<>kf then iddlekey=0

if iddlekey=0

   if lastkey=kl and mario_pos>0
    mario_old_pos=mario_pos 
    mario_pos=mario_pos-1
    iddlekey=1   
   end if
   
   if lastkey=kr and mario_pos<4
    inc_puntos()
    mario_old_pos=mario_pos
    mario_pos=mario_pos+1 
    iddlekey=1
   end if
   
   if lastkey=kf 
    manos_changed=1
    iddlekey=1
   end if
end if



if mario_old_pos<>mario_pos or manos_changed=1

    if manos_changed=0 borra(mario_old_pos*3+10):PlaySFX(4) 
    if manos_arriba=1 borra(mario_old_pos*3+11) else borra(mario_old_pos*3+12)
    if manos_changed=0 pinta(mario_pos*3+10)    
    if manos_changed=1 
        if manos_arriba=0 then manos_arriba=1 else manos_arriba=0
        manos_changed=0
        PlaySFX(6)
    end if
    if manos_arriba=1 pinta(mario_pos*3+11) else pinta(mario_pos*3+12)
    mario_old_pos=mario_pos

end if


for n=0 to 4
    if mario_pos=n and ((manos_arriba=1 and tea(n,0)=3) or (manos_arriba=0 and puro(0)=8-n)) then 
        mario_explota(mario_pos)
        misses=misses+1
        pinta_misses()
        score_mode=1' turn off chance mode if is on
        goto start_life
    end if    
next n


if mario_pos=4 and manos_arriba=1 and quarterback=1
    lanza_bomba(300)
    if bombas_ok=5 then charly_explota():goto after_charly_explota
    borra(59):borra(22)'borra mario de la izquierda'
    goto after_bomb
end if

if score_mode=2 then 
    if frames mod 20=10  pinta_puntos(1)
    if frames mod 20=0  borra_puntos()
end if


oldframes=frames
waitretrace(1)
frames=frames+1
frames_quarterback=frames_quarterback+(frames-oldframes)

loop	

function cap(a$ as string) as string
    if (code(a$)>96 and code(a$)<123) then a$=chr(code(a$)-32)
    if a$=" " then a$="SP"
    return a$
end function

sub manual()
dim n as ubyte
LoadSDBank("manual.bin",0,0,0,160)
NextReg($12,80)
pause0()
paper 7:ink 0: bright 1:cls
printat42(0,15)
ink 2
print42("HOW TO PLAY")
ink 0
printat42(2,0)
print42("Mario's orders are to go into the jungle, receive a bomb from his buddy on the left side, then deliver to his buddy on the    right side to blow up the enemy. The enemytries to blow up the bomb with torches    while Mario is running with it. The Heavy Smoker tries to ignite the spilled oil to blow up Mario's bomb.")
printat42(10,0)
print42("Mario has to raise and lower the bomb to  maneuver the bomb safely to his buddies.")

ink 2
printat42(13,17)
print42("CONTROLS")
ink 0
printat42(15,0) 
print42(" Left: """+cap(kl)+""" - Right: """+cap(kr)+""" - Swap Bomb: """+cap(kf)+"""")

ink 2
printat42(17,18)
print42("POINTS")
ink 0
printat42(19,0) 
ink 0:print42("- "): ink 1 : print42(" 1 Pt. "): ink 0 : print42("when Mario goes right.")
printat42(20,0) 
ink 0:print42("- "): ink 1: print42(" 5 Pt. "): ink 0 : print42("when Mario delivers the bomb.")
printat42(21,0) 
ink 0:print42("- "): ink 1 : print42("10 Pt. "): ink 0 : print42("when 5 bombs are launched.")
printat42(22,0) 
print42("         (Maximum score displayed is 999)")

pause0()
cls

ink 2
printat42(0,17)
print42("MISS")
ink 0
printat42(2,0) 
print42("When Mario loses to a torch or oil fire,  he gets blown up and has to retreat to hisside of the screen. Three misses and game ends.")

ink 2
printat42(6,17)
print42("BONUS")
ink 0
printat42(8,0) 
print42("when Score reaches 300 points and there   are misses, all misses are cleared. ")
printat42(10,0) 
print42("If there are no misses when 300 score is  reached game goes in ""CHANCE TIME"" having double score until next miss.")

ink 2
printat42(14,16) 
print42("THANKS")

ink 0
printat42(16,0) 
ink 1:print42(" - Jose Rguez (Boriel)  "): ink 0 : print42("for his compiler.")
printat42(17,0) 
ink 1:print42(" - David Saphier  "): ink 0 : print42("for his NextBuild Lib.")
printat42(18,0) 
ink 1:print42(" - Duefectu  "): ink 0 : print42("for his ZX Basic book.")
printat42(19,0) 
ink 1:print42(" - Tomaz Kragelj  "): ink 0 : print42("for his asm book.")
printat42(20,0) 
ink 1:print42(" - Javi Ortiz  "): ink 0 : print42("for his support. (and idea)")
printat42(21,0) 
ink 1:print42(" - David Programa  "): ink 0 : print42("for his testing.")
printat42(22,0) 
ink 1:print42(" - Paco Vespa  "): ink 0 : print42("for his testing.")
printat42(23,0) 
ink 1:print42(" - Lee Bee  "): ink 0 : print42("for his song Bomber Bot.")

pause0()
paper 3:ink 0:border 3: bright 0:cls
NextReg($12,85)
end sub


sub pinta_misses()

for n=1 to 3
    poke @mode,1'borra 
    pinta_sprite_xy_num(41,(n-1)*19,5)
next n   
for n=1 to misses
    poke @mode,0'pinta
    pinta_sprite_xy_num(41,(n-1)*19,5)
next n

end sub

sub parpadea_llama()
    dim n,llama as ubyte
    
    llama=50+mario_pos+manos_arriba*80

    for n=0 to 2
        playsfx(10)
        pinta(llama)
        waitretrace(260)
        borra(llama)
        waitretrace(260)
    next n
        
end sub

sub pinta_puntos(modo as ubyte)
    dim n as ubyte
    dim c(2) as uinteger
    c(0)=puntos/100
    c(1)=(puntos-c(0)*100)/10
    c(2)=puntos mod 10

    for n=0 to 2   
     if  (c(n)<>c_old(n) and score_mode=1) or modo=1
        poke @mode,1'borra 
        pinta_sprite_xy_num(70,270+12*n,5)
        poke @mode,0'pinta
        pinta_sprite_xy_num(60+c(n),270+12*n,5)
        c_old(n)=c(n)
    end if
    next n

end sub

sub borra_puntos()
    poke @mode,1'borra 
    for n=0 to 2    
        pinta_sprite_xy_num(70,270+12*n,5)
    next n
    poke @mode,0'pinta 
end sub

sub mario_explota(pos as ubyte)
    dim n as ubyte
    parpadea_llama()
    playsfx(1)
    waitretrace(300)

    for n=0 to 4
        borra(100+n)
        borra(110+n)
        borra(120+n)
        borra(130+n)
        tea(n,0)=0
    next n    

    for n=pos to 1 step -1
        anim_paso_atras(n,200)
    next n   

    waitretrace(200)
    anim_final(200)
    waitretrace(200)
    
end sub

sub lanza_bomba(pausa as uinteger)
    dim n as ubyte
    PlaySFX(7)
    waitretrace(pausa)
    borra(23)
    borra(32)
    pinta(33)
    pinta(35)
    pinta(59)
    for n=1 to 5 
    inc_puntos()
    next n
    waitretrace(pausa)
    borra(35)
    pinta(34)
    waitretrace(pausa/2)

    for n=1 to 5-bombas_ok
        playsfx(12+n)
        pinta(n+36)
        if n>1 borra(n+35)
        waitretrace(pausa)
    next n
    bombas_ok=bombas_ok+1
    borra(34)
end sub

sub charly_explota()

  for nn=0 to 3
        for n=0 to 4
            borra(37+n)
        next n
        waitretrace(200)
        for n=0 to 4
            pinta(37+n)
        next n
        waitretrace(200)
    next nn

    for n=0 to 4
        borra(80+n)
        borra(90+n)
        borra(100+n)
        borra(110+n)
        borra(120+n)
        borra(130+n)
        pinta(70+n)
    next n

    waitretrace(1000)
    for n=0 to 4
        borra(37+n)
        borra(70+n)
    next n
 
    'waitretrace(1000)
    playsfx(11)
    pinta(47)

  
    for n=0 to 9
        ScrollLayer(0,-3)
        waitretrace(50)
        ScrollLayer(0,0)
        waitretrace(50)
    next n
    waitretrace(1500)

    for n=0 to 9
        inc_puntos()
    next n  
end sub

sub inc_puntos()
'playsfx(8)
puntos=puntos+score_mode

if puntos=300 then
    playsfx(9)
    if misses>0 then 
        misses=0
        pinta_misses()
    else
        score_mode=2 'chance mode'
    end if
end if
if puntos>=1000 then puntos=999

if puntos mod 100=0 then 'recalcula velocidades
    freq_qua_up=freq_qua_up+10
    freq_qua_down=freq_qua_down-1
    freq_tea=freq_tea-1
    freq_puro=freq_puro-2   
end if
pinta_puntos(0)
end sub

sub pause0()
    do
        inkey_joy()
    loop until lastkey<>""
    do 
        inkey_joy()
    loop while lastkey<>""
end sub

sub sprite(sp as ubyte,modo as ubyte)
    poke @mode,modo 
    if sp>=70 and sp<80 'charly arriba
        pinta_sprite_xy_num(36,spxy(36,0)+43*(sp-70),spxy(36,1))
    else if sp>=80 and sp<90 'charly medio
        pinta_sprite_xy_num(26,spxy(26,0)+43*(sp-80),spxy(26,1))
    else if sp>=90 and sp<100 'charly abajo
        pinta_sprite_xy_num(25,spxy(25,0)+43*(sp-90),spxy(25,1))
    else if sp>=100 and sp<110 'torch up'
        pinta_sprite_xy_num(27,spxy(27,0)+43*(sp-100),spxy(27,1))
    else if sp>=110 and sp<120 'torch mid'
        pinta_sprite_xy_num(28,spxy(28,0)+43*(sp-110),spxy(28,1))
    else if sp>=120 and sp<130 'torch down'
        pinta_sprite_xy_num(29,spxy(29,0)+43*(sp-120),spxy(29,1))
    else if sp>=130 and sp<140 'fire palm'
        pinta_sprite_xy_num(30,spxy(30,0)+43*(sp-130),spxy(30,1))
    else
        pinta_sprite_xy_num(sp,spxy(sp,0),spxy(sp,1))
    end if
end sub

sub pinta_escenario()
    dim n as ubyte
    pinta(0)
    pinta(55)
    pinta(42)
    pinta(43)
    pinta(31)
    pinta(33)
    for n=0 to 4
        pinta_sprite_xy_num (48,spxy(48,0)+n*43,spxy(48,1))
    next n

end sub

sub borra(sp as ubyte)
    sprite(sp,1)
end sub
sub pinta(sp as ubyte)
    sprite(sp,0)
end sub

sub intro_first(espera as uinteger)
    pinta(10)
    pinta(57)
    pinta(2)
    waitretrace(espera)
    borra(2)
    pinta(1)
    pinta(3)
    playsfx(4)
    waitretrace(espera)
    borra(3)
    pinta(58)
    waitretrace(espera)
    borra(58)
    borra(57)
    pinta(12)
    borra(1)

end sub

sub intro(espera as uinteger)
    intro_first(espera)
    waitretrace(espera)
    borra(10)
    borra(12)
    pinta(13)
    pinta(15)
    waitretrace(espera)
    pinta(80)
    waitretrace(espera)
    borra(80)
    pinta(81)
    pinta(16)
    pinta(18)
    borra(13)
    borra(15)
    waitretrace(espera)
    borra(81)
    pinta(82)
    waitretrace(espera)
    borra(18)
    pinta(17)
    borra(82)
    pinta(83)
    borra(33)
    pinta(32)
    waitretrace(espera)
    borra (83)
    pinta (84)
    waitretrace(espera)
    borra (16)
    borra (17)
    pinta (19)
    pinta (20)
    pinta (104)
    waitretrace(espera)
    borra(104)
    pinta(114)
    waitretrace(espera)
    borra(32)
    pinta(33)
    borra(114)
    pinta(124)
    pinta(134)
    waitretrace(espera)
    borra(19)
    borra(20)
    pinta (22)
    pinta(23)
    waitretrace(espera)
    borra(134)  
    waitretrace(espera)
    pinta(134)
    waitretrace(espera)
    borra(124)
    playsfx(1)
for n=4 to 1 step -1
    anim_paso_atras(n,espera) 
next n
anim_final(espera)
end sub

sub anim_paso_atras(pos as ubyte, espera as uinteger)
    borra(130+pos)
    pinta(129+pos)
    borra(10+pos*3)
    borra(11+pos*3)
    borra(12+pos*3)
    pinta(10+(pos-1)*3) 
    pinta(11+(pos-1)*3) 
    waitretrace(espera)
end sub

sub anim_final(espera as uinteger)    
    borra(130 )
    borra(11)
    borra(10)
    borra(12)
    pinta(6)
    pinta(7)
    pinta(4)
 
    for n=80 to 84
        borra(n)
        pinta(n+10)
    next n

    waitretrace(espera)
    pinta(8)
    waitretrace(espera)
    borra(7)
    borra(4)
    pinta(9)
    playsfx(2)
    waitretrace(espera)
    borra(0)
    pinta(49)

    for n=0 to 9
        ScrollLayer(0,-3)
        waitretrace(50)
        ScrollLayer(0,0)
        waitretrace(50)
    next n
    borra(49)
    borra(8)
    borra(9)
    borra(6)

end sub

function getkey(k1 as string,k2 as string,k3 as string) as string
dim a$ as string
mas:
do while inkey$=""
loop
    a$=inkey$
    if a$<>k1 and a$<>k2 and a$<>k3 and ((code(a$)>96 and code(a$)<123)or(code(a$)>47 and code(a$)<58) or code(a$)=32)
        Playsfx(4)
    else 
        Playsfx(6)
        goto mas
    end if
return a$
end function


sub redefine()
    dim x,y,n as ubyte
    ink 4
    paper 0
    
    for n=6 to 12
        print at n,2; "                            "
    next n
   
    do
    loop until inkey$=""
    print at 7,5;"Move Mario Left:"
    print at 9,5;"Move Mario Right:"
    print at 11,5;"Swap bomb up/down: "
    print at 7,26;"_"
    kl=getkey(".",".",".")
    print at 7,26;cap(kl)

    print at 9,26;"_"
    kr=getkey(kl,".",".")
    print at 9,26;cap(kr)

    print at 11,26;"_"
    kf=getkey(kl,kr,".")
    print at 11,26;cap(kf)
    pause0()
    pause0()
    paper 3
    cls
end sub


sub fastcall breakpoint()
    asm
        db $dd,$01
    end asm 
end sub

sub fastcall pinta_sprite_xy_num( num as ubyte, x as uinteger,y as ubyte)
asm
; Usamos el primer banco de ROM (0000-1FFF) para mapear los sprites fuente
; Usamos el segundo banco de ROM (2000-3FFF) para mapear 8Kb de los 80Kb de la pantalla
;db $dd,$01
di

ld (saveix),ix

ld b,a
ld a,(source_page)
nextreg $50,a; en el 38 de 8 kb hemos cargado los sprites
ld a,b

ld hl,0000; 

;calcula DE a partir de A

cp 0
jr z, addrsourceok
ld b,a

ld a,(source_page)
ld ixl,a

loop_de:
    ld e,(hl); lx del sprite b
    inc hl
    ld d,(hl); ly del sprite b
    inc hl
    mul d,e
    add hl,de

    bit 5,h
    jr z, source_page_still_ok1
        res 5,h
        inc ixl
        ld a,ixl
        nextreg $50,a
    source_page_still_ok1:

    ; Problema 1: Estamos limitados a 64Kb de tamaño del archivo de sprites. HL desbordaria.
  
djnz loop_de

addrsourceok:

push hl
pop ix

pop bc;bc=retorno

pop hl
;hl tiene la x 0-319
call setbank
;hl tiene la x 0-399 
pop de; de=y+??



ld a,l
and %00011111
ld h,a

ld l,d
ld de,$2000
add hl,de
;hl tiene la addr destino

push ix
pop de

push bc; guarda el retorno

;hl tiene la addr de pantalla'
;de tiene la addr fuente del sprite en memoria


getreg($50)	 
LD IXL, A ;current source page on ixl


ld a,(de)
ld b,a; b tiene lx
inc de
ld a,(de)
ld c,a; c tiene ly
inc de

loopx:

    push bc 
    push hl
    ld b,c ; c tiene el tamaño y
loopy:
    bit 5,d
    jr z, source_page_still_ok
    res 5,d 
    inc ixl
    ld a,ixl
    nextreg $50,a
    source_page_still_ok:

    ld a, (de)
    
    ;if a>0
    ;if modo=AND
    ;    pinta el pixel
    ;else (modo OR)
    ;    pinta 0
    or a
    jr z, nolopintes

    ld a,(mode)
    or a
    ld a,0
    jr nz,modo1;(borra)
    ld a,(de) 
modo1:
    ld (hl),a
 nolopintes:   
    inc de
    inc hl
    djnz loopy
    pop hl
    inc h
    ld a,$40
    cp h
    jr nz, nocambiacol
    ld h,$20
    ld a,(currentbank)
    inc a
    nextreg $51,a
    ld (currentbank),a
nocambiacol:    
    pop bc
    djnz loopx

jr fin

setbank:
    ld a, h
    or a
    jp nz, esmayor255
    ld a,l
    srl a
    srl a
    srl a
    srl a
    srl a
    jr graba56
esmayor255:
    ld a,l
    sla a
    sla a
    sla a
    ld a,9
    jr c, graba56
    ld a,8
graba56:
    add a,100
    nextreg $51,a
    ld (currentbank),a
    ret
currentbank:
    db 00
fin:    
nextreg $50,255
nextreg $51,255

ld ix,(saveix)
ei

end asm
end sub

mode:
asm
mode:
db 0
saveix:
db 0,0
end asm


source_page:
asm
source_page:
db 38
end asm




sub fastcall cls320x256(color as ubyte)
asm
nextreg $51,100
call deleteblock
nextreg $51,101
call deleteblock
nextreg $51,102
call deleteblock
nextreg $51,103
call deleteblock
nextreg $51,104
call deleteblock
nextreg $51,105
call deleteblock
nextreg $51,106
call deleteblock
nextreg $51,107
call deleteblock
nextreg $51,108
call deleteblock
nextreg $51,109
call deleteblock
jr fincls

deleteblock:
ld hl,$2000
ld de,$2001
ld (hl),a
ld bc,$1FFF
ldir
ret
fincls:
end asm
end sub

sub inkey_joy()
    lastkey=inkey$()
    if in(31)=1 then lastkey=kr
    if in(31)=2 then lastkey=kl
    if in(31)=16 then lastkey=kf
end sub

sub setup_joystick()
    dim r as ubyte
    r = GetReg($05)
    r = r bAND %00110011
    r = r bOR  %01000000
    NextRegA($05,r)
end sub

sub font()
asm
; Standstill font by DamienG https://damieng.com
defb $00,$00,$00,$00,$00,$00,$00,$00 ;  
defb $18,$3c,$3c,$18,$00,$18,$18,$00 ; !
defb $6c,$6c,$6c,$00,$00,$00,$00,$00 ; "
defb $00,$6c,$ee,$6c,$6c,$ee,$6c,$00 ; #
defb $00,$28,$6e,$e0,$6c,$0e,$ec,$28 ; $
defb $20,$76,$2c,$18,$34,$6e,$04,$00 ; %
defb $68,$cc,$c0,$6e,$cc,$cc,$6e,$00 ; &
defb $18,$18,$18,$00,$00,$00,$00,$00 ; '
defb $18,$30,$30,$30,$30,$30,$18,$00 ; (
defb $30,$18,$18,$18,$18,$18,$30,$00 ; )
defb $00,$10,$7c,$38,$28,$00,$00,$00 ; *
defb $00,$18,$18,$7e,$18,$18,$00,$00 ; +
defb $00,$00,$00,$00,$00,$18,$18,$18 ; ,
defb $00,$00,$00,$7c,$00,$00,$00,$00 ; -
defb $00,$00,$00,$00,$00,$18,$18,$00 ; .
defb $0c,$0c,$18,$18,$30,$30,$60,$60 ; /
defb $28,$6c,$c6,$c6,$c6,$6c,$28,$00 ; 0
defb $38,$18,$18,$18,$18,$18,$3c,$00 ; 1
defb $2c,$66,$06,$1c,$30,$02,$7e,$00 ; 2
defb $2c,$66,$06,$0c,$06,$66,$2c,$00 ; 3
defb $0c,$2c,$2c,$4c,$6e,$0c,$1e,$00 ; 4
defb $7e,$00,$60,$6c,$06,$66,$2c,$00 ; 5
defb $2c,$66,$60,$6c,$66,$66,$2c,$00 ; 6
defb $7e,$40,$06,$0c,$0c,$18,$18,$00 ; 7
defb $34,$62,$72,$3c,$4e,$46,$2c,$00 ; 8
defb $34,$66,$66,$36,$06,$66,$34,$00 ; 9
defb $00,$18,$18,$00,$00,$18,$18,$00 ; :
defb $00,$18,$18,$00,$00,$18,$18,$18 ; ;
defb $00,$0e,$38,$f0,$38,$0e,$00,$00 ; <
defb $00,$00,$7c,$00,$7c,$00,$00,$00 ; =
defb $00,$e0,$38,$1e,$38,$e0,$00,$00 ; >
defb $2c,$66,$06,$0c,$00,$18,$18,$00 ; ?
defb $28,$6c,$c6,$ce,$d2,$ce,$60,$2e ; @
defb $18,$08,$2c,$2c,$5e,$46,$ef,$00 ; A
defb $ec,$66,$66,$6c,$66,$66,$ec,$00 ; B
defb $2a,$66,$c0,$c0,$c0,$66,$2c,$00 ; C
defb $e8,$64,$66,$66,$66,$64,$e8,$00 ; D
defb $ee,$66,$60,$68,$60,$66,$ee,$00 ; E
defb $ee,$66,$60,$70,$60,$60,$f0,$00 ; F
defb $2a,$66,$c0,$ce,$c6,$66,$2c,$00 ; G
defb $e7,$66,$66,$6e,$66,$66,$e7,$00 ; H
defb $3c,$18,$18,$18,$18,$18,$3c,$00 ; I
defb $1e,$0c,$0c,$0c,$cc,$cc,$68,$00 ; J
defb $ee,$64,$68,$60,$68,$64,$ee,$00 ; K
defb $f0,$60,$60,$60,$60,$66,$ee,$00 ; L
defb $e7,$66,$3a,$56,$46,$46,$ef,$00 ; M
defb $ee,$64,$34,$58,$4c,$4c,$ec,$00 ; N
defb $28,$6c,$c6,$c6,$c6,$6c,$28,$00 ; O
defb $ec,$66,$66,$66,$6c,$60,$f0,$00 ; P
defb $28,$6c,$c6,$c6,$da,$6c,$2e,$00 ; Q
defb $ec,$66,$66,$6c,$6c,$66,$e6,$00 ; R
defb $36,$62,$70,$3c,$0e,$46,$6c,$00 ; S
defb $db,$99,$18,$18,$18,$18,$3c,$00 ; T
defb $ee,$64,$64,$64,$64,$64,$28,$00 ; U
defb $e7,$62,$62,$34,$30,$18,$18,$00 ; V
defb $e7,$62,$6a,$68,$24,$34,$34,$00 ; W
defb $e6,$64,$30,$38,$18,$4c,$ce,$00 ; X
defb $f7,$62,$34,$30,$18,$18,$3c,$00 ; Y
defb $76,$46,$0c,$18,$30,$62,$6e,$00 ; Z
defb $3c,$30,$30,$30,$30,$30,$30,$3c ; [
defb $60,$60,$30,$30,$18,$18,$0c,$0c ; \
defb $3c,$0c,$0c,$0c,$0c,$0c,$0c,$3c ; ]
defb $10,$38,$6c,$00,$00,$00,$00,$00 ; ^
defb $00,$00,$00,$00,$00,$00,$00,$ff ; _
defb $14,$36,$30,$74,$30,$32,$76,$00 ; £
defb $00,$00,$78,$0c,$6c,$cc,$6e,$00 ; a
defb $e0,$60,$6c,$66,$66,$66,$6c,$00 ; b
defb $00,$00,$2c,$66,$60,$66,$2c,$00 ; c
defb $0e,$06,$36,$66,$66,$66,$37,$00 ; d
defb $00,$00,$2c,$66,$6e,$60,$2e,$00 ; e
defb $14,$36,$30,$74,$30,$30,$78,$00 ; f
defb $00,$00,$6e,$cc,$cc,$6c,$0c,$e8 ; g
defb $e0,$60,$6c,$66,$66,$66,$e6,$00 ; h
defb $18,$00,$38,$18,$18,$18,$3c,$00 ; i
defb $0c,$00,$1c,$0c,$0c,$0c,$6c,$28 ; j
defb $e0,$60,$66,$6c,$68,$6c,$ee,$00 ; k
defb $38,$18,$18,$18,$18,$18,$3c,$00 ; l
defb $00,$00,$d4,$d6,$d6,$d6,$d6,$00 ; m
defb $00,$00,$ec,$66,$66,$66,$e6,$00 ; n
defb $00,$00,$2c,$66,$66,$66,$2c,$00 ; o
defb $00,$00,$ec,$66,$66,$6c,$60,$f0 ; p
defb $00,$00,$6e,$cc,$cc,$6c,$0c,$1e ; q
defb $00,$00,$ec,$66,$60,$60,$e0,$00 ; r
defb $00,$00,$36,$60,$34,$06,$6c,$00 ; s
defb $10,$30,$74,$30,$30,$36,$14,$00 ; t
defb $00,$00,$e6,$66,$66,$66,$37,$00 ; u
defb $00,$00,$ee,$64,$30,$18,$18,$00 ; v
defb $00,$00,$f7,$62,$6a,$34,$34,$00 ; w
defb $00,$00,$76,$38,$18,$2c,$6e,$00 ; x
defb $00,$00,$ee,$64,$30,$18,$18,$70 ; y
defb $00,$00,$6e,$4c,$18,$32,$76,$00 ; z
defb $0c,$18,$18,$70,$18,$18,$18,$0c ; {
defb $18,$18,$18,$18,$18,$18,$18,$18 ; |
defb $30,$18,$18,$0e,$18,$18,$18,$30 ; }
defb $00,$76,$dc,$00,$00,$00,$00,$00 ; ~
defb $3c,$42,$95,$b5,$b1,$95,$42,$3c ; ©
end asm
end sub
