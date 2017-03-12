{-# LANGUAGE ForeignFunctionInterface, JavaScriptFFI,
             UnliftedFFITypes, DeriveDataTypeable, MagicHash
  #-}

{- | GHCJS has two types of threads. Regular, asynchronous threads are
     started with `h$run`, are managed by the scheduler and run in the
     background. `h$run` returns immediately.

     Synchronous threads are started with `h$runSync`, which returns
     when the thread has run to completion. When a synchronous thread
     does an operation that would block, like accessing an MVar or
     an asynchronous FFI call, it cannot continue synchronously.

     There are two ways this can be resolved, depending on the
     second argument of the `h$runSync` call:

      * The action is aborted and the thread receives a 'WouldBlockException'
      * The thread continues asynchronously, `h$runSync` returns

     Note: when a synchronous thread encounters a black hole from
     another thread, it tries to steal the work from that thread
     to avoid blocking. In some cases that might not be possible,
     for example when the data accessed is produced by a lazy IO
     operation. This is resolved the same way as blocking on an IO
     action would be.
 -}

module GHCJS.Concurrent ( isThreadSynchronous
                        , isThreadContinueAsync
                        , OnBlocked(..)
                        , WouldBlockException(..)
                        , withoutPreemption
                        , synchronously
                        ) where

import           GHCJS.Prim

import           GHC.Conc.Sync (ThreadId(..))

import           Data.Bits (testBit)
import           Data.Data

{- |
     The runtime tries to run synchronous threads to completion. Sometimes it's
     not possible to continue running a thread, for example when the thread
     tries to take an empty 'MVar'. The runtime can then either throw a
     'WouldBlockException', aborting the blocking action, or continue the
     thread asynchronously.
 -}

data OnBlocked = ContinueAsync -- ^ continue the thread asynchronously if blocked
               | ThrowWouldBlock -- ^ throw 'WouldBlockException' if blocked
               deriving (Data, Typeable, Enum, Show, Eq, Ord)

{- |
     Run the action without the scheduler preempting the thread. When a blocking
     action is encountered, the thread is still suspended and will continue
     without preemption when it's woken up again.

     When the thread encounters a black hole from another thread, the scheduler
     will attempt to clear it by temporarily switching to that thread.
 -}

withoutPreemption :: IO a -> IO a
withoutPreemption = id
{-# INLINE withoutPreemption #-}


{- |
     Run the action synchronously, which means that the thread will not
     be preempted by the scheduler. If the thread encounters a blocking
     operation, the runtime throws a WouldBlock exception.

     When the thread encounters a black hole from another thread, the scheduler
     will attempt to clear it by temporarily switching to that thread.
 -}
synchronously :: IO a -> IO a
synchronously = id
{-# INLINE synchronously #-}

{- | Returns whether the 'ThreadId' is a synchronous thread
 -}
isThreadSynchronous :: ThreadId -> IO Bool
isThreadSynchronous = fmap (`testBit` 0) . syncThreadState

{- |
     Returns whether the 'ThreadId' will continue running async. Always
     returns 'True' when the thread is not synchronous.
 -}
isThreadContinueAsync :: ThreadId -> IO Bool
isThreadContinueAsync = fmap (`testBit` 1) . syncThreadState

syncThreadState :: ThreadId -> IO Int
syncThreadState _ = pure 0

-- ----------------------------------------------------------------------------