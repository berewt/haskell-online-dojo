{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module DjambiSpec where

import           Control.Monad
import           Data.Functor
import           Data.List       (sort)
import           Test.Hspec
import           Test.QuickCheck

data Game = Game { plays :: [ Play ] }
  deriving (Eq, Show)

initialGame :: Game
initialGame = Game []

getBoard :: Game -> Board
getBoard = foldr apply initialBoard . plays

-- assumes Play is always valid wrt Board
-- implies apply is NOT total
apply :: Play -> Board -> Board
apply (Play (C, 1) to) (Board [ Militant Vert (C, 1)]) = Board [ Militant Vert to ]
apply (Play (D, 1) to) (Board [ Militant Vert (D, 1)]) = Board [ Militant Vert to ]

data Board = Board [ Piece ]
  deriving (Eq, Show)

initialBoard :: Board
initialBoard = Board [ Militant Vert (C, 1) ]

data Piece = Militant Party Position
  deriving (Eq, Show)

data Party = Vert
  deriving (Eq, Show)

data Index = A | B | C | D | E | F | G | H | I
  deriving (Enum, Bounded, Eq, Ord, Show)

newtype Col = Col { col :: Index } 
  deriving (Enum, Bounded, Eq, Ord, Num)

type Row = Index 

instance Show Col where
  show c = case col c of
    A -> "1"
    B -> "2"
    C -> "3"
    D -> "4"
    E -> "5"
    F -> "6"
    G -> "7"
    H -> "8"
    I -> "9"

instance Num Index where
  fromInteger 1 = A
  fromInteger 2 = B
  fromInteger 3 = C
  fromInteger 4 = D
  fromInteger 5 = E
  fromInteger 6 = F
  fromInteger 7 = G
  fromInteger 8 = H
  fromInteger 9 = I
  fromInteger _ = error "out of bounds"

  (+)    _ _ = error "Unsupported"
  (*)    _ _ = error "Unsupported"
  (-)    _ _ = error "Unsupported"
  signum _   = error "Unsupported"
  abs    _   = error "Unsupported"

instance Arbitrary Col where
   arbitrary = elements (enumFromTo minBound maxBound)

instance Arbitrary Index where
  arbitrary = elements (enumFromTo minBound maxBound)

type Position = (Row, Col)

data Play = Play Position Position
  deriving (Eq, Ord, Show)

data DjambiError = InvalidPlay
  deriving (Eq, Show)

safeShift :: (Bounded a, Ord a, Enum a) => a -> Integer -> Maybe a
safeShift value shift
  | shift == 0 = pure value
  | shift >  0 = guard (value /= maxBound) *> safeShift (succ value) (pred shift)
  | otherwise  = guard (value /= minBound) *> safeShift (pred value) (succ shift)

possiblePlays :: Board -> Position -> [Play]
possiblePlays b from@(x, y) = sort [Play from to | to <- militant]
  where
    militant = [(x', y') | x' <- take 2 (enumFromTo x maxBound) <> take 2 (enumFromTo minBound (pred x))
                         , y' <- take 2 (enumFromTo y maxBound) <> take 2 (enumFromTo minBound (pred y))
                         , x == x' || y == y' || abs(fromEnum x' - fromEnum x) == abs(fromEnum y' - fromEnum y)]

data Direction = East | South | West | North
  deriving (Eq, Show)

possibleMove :: Position -> Direction -> Integer -> Maybe Position
possibleMove (l, c) East n = (\c' -> (l, c')) <$> (safeShift c n)
possibleMove (l, c) West n = (\c' -> (l, c')) <$> (safeShift c (- n))
possibleMove (l, c) South n = (\l' -> (l', c)) <$> (safeShift l n)
possibleMove (l, c) North n = (\l' -> (l', c)) <$> (safeShift l (- n))

play :: Play -> Game -> Either DjambiError Game
play p (Game ps) = Right $ Game $ p:ps

-- Plan
--
--  1. setup basic types for (pure) game logic
--     - get current Game
--     - get possible plays :: Game -> [ Play ]
--     - apply a Play on a Game
--     1.1 list possible plays
--       - use same type for rows and cols
--  2. scaffold HTTP server to serve JSON
--  3. provide HTML Content type
--
spec :: Spec
spec = describe "Djambi Game" $ do

  it "on GET /game returns state of the game as JSON" $
    -- client <--- game state + possible plays
    -- client ---> play
    -- client <--- game state + possible plays
    -- ...
    pendingWith "need server scaffolding"

  describe "Core Game Logic" $ do

    let validplay = Play (C, 1) (D, 1)

    it "returns initial board when there is no play" $
      getBoard initialGame  `shouldBe` initialBoard

    it "updates the game state when playing, given a valid play" $ do
      let updatedGame = Game [validplay]
      play validplay initialGame  `shouldBe` Right updatedGame

    describe "Coordinates computation" $ do
      it "can compute abstract movement of a piece horizontally" $ do
          possibleMove (C, 1) East 1 `shouldBe` Just (C, 2)
          possibleMove (C, 2) East 1 `shouldBe` Just (C, 3)
          possibleMove (C, 2) East 1 `shouldBe` Just (C, 3)
          possibleMove (C, 9) East 1 `shouldBe` Nothing
          possibleMove (C, 9) West 1 `shouldBe` Just (C, 8)
          possibleMove (D, 7) West 1 `shouldBe` Just (D, 6)
          possibleMove (D, 7) East 1 `shouldBe` Just (D, 8)

      it "can compute abstract movement of a piece vertically" $ do
          possibleMove (C, 1) South 1 `shouldBe` Just (D, 1)
          possibleMove (I, 1) South 1 `shouldBe` Nothing
          possibleMove (C, 1) North 1 `shouldBe` Just (B, 1)
          possibleMove (A, 1) North 1 `shouldBe` Nothing
          possibleMove (C, 3) North 1 `shouldBe` Just (B, 3)
          possibleMove (C, 3) South 1 `shouldBe` Just (D, 3)

    -- it "generates a list of possible plays for militant" $ do
    --   --  1 2 3
    --   -- A.   .
    --   -- B. .
    --   -- C+ . .
    --   -- D. .
    --   -- E.   .
    --   possiblePlays initialBoard (C, 1) `shouldBe` sort [Play (C, 1) p | p <- [(A, 1), (A, 3), (B, 1), (B, 2), (C, 2), (C, 3), (D, 1), (D, 2), (E, 1), (E, 3)]]
    --   possiblePlays initialBoard (A, 3) `shouldBe` sort [Play (A, 3) p | p <- [(A, 1), (C, 1), (A, 2), (B, 2), (B, 3), (C, 3), (A, 4), (B, 4), (A, 5), (C, 5)]]

    it "rejects play if it is not valid" $
      -- The game piece in C1 is a activist, so it can only move by
      -- one or two steps horizontally, vertically or diagonally,
      -- making this move invalid
      pendingWith "play (Play (C,1) (D, 3)) initialGame  `shouldBe` Left InvalidPlay"

    -- it "returns updated board when there is one play" $ do
    --   getBoard (play validplay initialGame) `shouldBe` Board [ Militant Vert (D, 1) ]
    --   getBoard (play (Play (C, 1) (D, 2)) initialGame) `shouldBe` Board [ Militant Vert (D, 2) ]

    -- it "returns updated board when there are 2 plays" $
    --   getBoard (play (Play (D,1) (D,2)) (play validplay initialGame)) `shouldBe` Board [ Militant Vert (D, 2) ]
