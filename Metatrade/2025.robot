//+------------------------------------------------------------------+
//|  EA Minimize Loss Example (MQL5) - Perbaikan                      |
//|  WARNING: NO GUARANTEE; test on demo first                        |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

//--- inputs
input int    analisis           = 1;    // 1=force buy, 0=force sell, -1=use signal
input double fixed_lot          = 0.10; // jika use_risk=false
input bool   use_risk           = true; // jika true gunakan risk_percent untuk sizing
input double risk_percent       = 1.0;  // % dari balance per trade (jika use_risk)
input int    sl_pips            = 80;   // stop loss pips
input int    tp_pips            = 160;  // take profit pips
input int    ema_period         = 200;
input int    sto_k              = 5;
input int    sto_d              = 3;
input int    sto_slowing        = 3;
input int    rsi_period         = 14;
input double rsi_entry_buy_min  = 40.0; // RSI harus > ini untuk buy (konfirmasi trend)
input double rsi_entry_sell_max = 60.0; // RSI harus < ini untuk sell (konfirmasi trend)
input int    max_trades_per_day = 2;
input double max_daily_loss_pct = 5.0;  // stop trading jika rugi > X% hari ini
input int    max_consec_losses  = 3;
input int    slippage           = 20;   // deviation (points)
input bool   enable_trailing    = true;
input int    trailing_start_pips= 40;
input int    trailing_step_pips = 20;

//--- globals
datetime lastTradeDay = 0;
int tradesToday = 0;
int consecutiveLosses = 0;
double dailyLoss = 0.0;

// indicator handles
int hEMA=INVALID_HANDLE;
int hSto=INVALID_HANDLE;
int hRSI=INVALID_HANDLE;

//+------------------------------------------------------------------+
double PipsToPoints(int pips)
{
      double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
         int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
            // Jika broker 5-digit atau 3-digit, fractional pip => pip = 10 * point
               double factor = (digits==3 || digits==5) ? 10.0 : 1.0;
                  return pips * factor * point;
}

// simple lot calc (approx): risk% of balance divided by (SL in price * value per 1.0 price move per lot)
double CalculateLot(double risk_percent, int sl_pips)
{
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         double risk_amt = balance * risk_percent / 100.0;
            double sl_price = MathAbs(PipsToPoints(sl_pips)); // price distance in price units

               // get tick / contract info
                  double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE); // value per tick per lot
                     double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);  // tick size
                        if(tick_value<=0 || tick_size<=0)
                           {
                                    // fallback
                                          Print("Tick info invalid, falling back to fixed_lot.");
                                                return NormalizeDouble(fixed_lot,2);
                           }

                              double value_per_point_per_lot = tick_value / tick_size; // value per 1.0 price move per 1 lot
                                 if(value_per_point_per_lot<=0)
                                    {
                                             Print("Value per point invalid, fallback to fixed lot.");
                                                   return NormalizeDouble(fixed_lot,2);
                                    }

                                       double lot = risk_amt / (sl_price * value_per_point_per_lot);

                                          // normalize to broker limits
                                             double minlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                                                double maxlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
                                                   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
                                                      if(step<=0) step = 0.01;

                                                         // don't exceed
                                                            if(lot < minlot) lot = minlot;
                                                               if(lot > maxlot) lot = maxlot;

                                                                  // round down to step to avoid exceeding allowed lot
                                                                     double steps = MathFloor(lot/step);
                                                                        lot = steps * step;
                                                                           if(lot < minlot) lot = minlot;

                                                                              // normalize to reasonable decimals (broker step precision)
                                                                                 int digits = (int)MathMax(0.0, MathLog10(1.0/step));
                                                                                    if(digits<0) digits = 2;
                                                                                       return NormalizeDouble(lot, digits);
}

// update midnight counters and compute today's P/L using history
void UpdateDailyCounters()
{
      datetime t = TimeCurrent();
         MqlDateTime dt; TimeToStruct(t, dt);
            // set to midnight
               dt.hour = 0; dt.min = 0; dt.sec = 0;
                  datetime dayStart = StructToTime(dt);

                     if(lastTradeDay != dayStart)
                        {
                                 // new day -> recalc stats
                                       tradesToday = 0;
                                             consecutiveLosses = 0;
                                                   dailyLoss = 0.0;
                                                         lastTradeDay = dayStart;

                                                               // compute today's P/L and consecutive losses from history (simple approach)
                                                                     // select history from midnight to now
                                                                           if(HistorySelect(dayStart, t))
                                                                                 {
                                                                                             ulong deals_total = HistoryDealsTotal();
                                                                                                      double loss_sum = 0.0;
                                                                                                               int consec_losses = 0;
                                                                                                                        // loop all deals and sum profit of closed deals (deals_total may be 0)
                                                                                                                                 for(ulong i=0; i<deals_total; i++)
                                                                                                                                          {
                                                                                                                                                         ulong ticket = HistoryDealGetTicket(i);
                                                                                                                                                                     if(ticket==0) continue;
                                                                                                                                                                                 // get profit for this deal
                                                                                                                                                                                             double dp = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                                                                                                                                                                                                         double dvolume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
                                                                                                                                                                                                                     long dtype = (long)HistoryDealGetInteger(ticket, DEAL_ENTRY); // entry type
                                                                                                                                                                                                                                 // sum negative profit (loss)
                                                                                                                                                                                                                                             if(dp < 0.0) loss_sum += dp;
                                                                                                                                          }
                                                                                                                                                   dailyLoss = loss_sum; // negative if net loss
                                                                                                                                                            // consecutive losses estimation: check last few closed trades (by deals)
                                                                                                                                                                     // get last N deals and count consecutive negative deals up to a positive
                                                                                                                                                                              int count = 0;
                                                                                                                                                                                       for(long idx = (long)deals_total-1; idx>=0 && idx>= (long)deals_total-20; idx--)
                                                                                                                                                                                                {
                                                                                                                                                                                                               ulong tkt = HistoryDealGetTicket((ulong)idx);
                                                                                                                                                                                                                           if(tkt==0) continue;
                                                                                                                                                                                                                                       double profit = HistoryDealGetDouble(tkt, DEAL_PROFIT);
                                                                                                                                                                                                                                                   if(profit < 0) count++;
                                                                                                                                                                                                                                                               else break;
                                                                                                                                                                                                }
                                                                                                                                                                                                         consecutiveLosses = count;
                                                                                 }
                        } else {
                                 // same day: still update dailyLoss by reselecting recent history each tick for accuracy
                                       datetime now = TimeCurrent();
                                             if(HistorySelect(lastTradeDay, now))
                                                   {
                                                               ulong deals_total = HistoryDealsTotal();
                                                                        double loss_sum = 0.0;
                                                                                 for(ulong i=0; i<deals_total; i++)
                                                                                          {
                                                                                                         ulong ticket = HistoryDealGetTicket(i);
                                                                                                                     if(ticket==0) continue;
                                                                                                                                 double dp = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                                                                                                                                             if(dp < 0.0) loss_sum += dp;
                                                                                          }
                                                                                                   dailyLoss = loss_sum;
                                                                                                            // update consecutive losses quickly (last 20 deals)
                                                                                                                     int count = 0;
                                                                                                                              for(long idx = (long)deals_total-1; idx>=0 && idx>= (long)deals_total-20; idx--)
                                                                                                                                       {
                                                                                                                                                      ulong tkt = HistoryDealGetTicket((ulong)idx);
                                                                                                                                                                  if(tkt==0) continue;
                                                                                                                                                                              double profit = HistoryDealGetDouble(tkt, DEAL_PROFIT);
                                                                                                                                                                                          if(profit < 0) count++;
                                                                                                                                                                                                      else break;
                                                                                                                                       }
                                                                                                                                                consecutiveLosses = count;
                                                   }
                        }
}

// Check daily loss limit
bool DailyLossExceeded()
{
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         if(balance<=0) return true;
            // dailyLoss is negative if overall loss; convert to positive percent
               double lossAbs = MathAbs(dailyLoss);
                  double pct = (lossAbs / balance) * 100.0;
                     return (pct >= max_daily_loss_pct);
}

// create indicator handles
int OnInit()
{
      // EMA handle
         hEMA = iMA(_Symbol, _Period, ema_period, 0, MODE_EMA, PRICE_CLOSE);
            if(hEMA==INVALID_HANDLE) { Print("Failed create EMA handle"); return INIT_FAILED; }

               // Stochastic handle: buffers: 0 -> main %K, 1 -> signal %D
                  hSto = iStochastic(_Symbol, _Period, sto_k, sto_d, sto_slowing, MODE_SMA, STO_LOWHIGH);
                     // Note: STO_LOWHIGH is used for price field (see MQL5 enum). If compilation complains, try ENUM_STO_PRICE constants.
                        if(hSto==INVALID_HANDLE) { Print("Failed create Stochastic handle"); return INIT_FAILED; }

                           // RSI handle
                              hRSI = iRSI(_Symbol, _Period, rsi_period, PRICE_CLOSE);
                                 if(hRSI==INVALID_HANDLE) { Print("Failed create RSI handle"); return INIT_FAILED; }

                                    // initialize daily counters
                                       UpdateDailyCounters();

                                          return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
      if(hEMA != INVALID_HANDLE) IndicatorRelease(hEMA);
         if(hSto != INVALID_HANDLE) IndicatorRelease(hSto);
            if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
}

// helper: get latest EMA value (shift 1 = last closed bar)
double GetEMAValue(int shift=1)
{
      double buf[];
         if(CopyBuffer(hEMA, 0, shift, 1, buf) == 1) return buf[0];
            return EMPTY_VALUE;
}

// helper: get stochastic main K and D (last closed bar)
bool GetStochastic(double &k, double &d, int shift=1)
{
      double bufK[], bufD[];
         int copiedK = CopyBuffer(hSto, 0, shift, 1, bufK); // main
            int copiedD = CopyBuffer(hSto, 1, shift, 1, bufD); // signal
               if(copiedK==1 && copiedD==1)
                  {
                           k = bufK[0]; d = bufD[0];
                                 return true;
                  }
                     return false;
}

// helper: get RSI value (last closed bar)
double GetRSI(int shift=1)
{
      double buf[];
         if(CopyBuffer(hRSI, 0, shift, 1, buf) == 1) return buf[0];
            return EMPTY_VALUE;
}

// check if any position open on symbol
bool HasOpenPosition()
{
      return PositionSelect(_Symbol);
}

// trailing stop handler - simple implementation
void ManageTrailing()
{
      if(!enable_trailing) return;
         // iterate positions for this symbol
            if(!PositionSelect(_Symbol)) return;
               // only handle single position for simplicity
                  ulong ticket = PositionGetInteger(POSITION_TICKET);
                     double pos_volume = PositionGetDouble(POSITION_VOLUME);
                        double pos_price = PositionGetDouble(POSITION_PRICE_OPEN);
                           double pos_sl = PositionGetDouble(POSITION_SL);
                              long pos_type = (long)PositionGetInteger(POSITION_TYPE); // POSITION_TYPE_BUY / SELL
                                 double current_price = (pos_type==POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
                                    double profit_price_diff = (pos_type==POSITION_TYPE_BUY) ? (current_price - pos_price) : (pos_price - current_price);
                                       // convert profit_price_diff to pips
                                          double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
                                             int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
                                                double factor = (digits==3 || digits==5) ? 10.0 : 1.0;
                                                   double profit_pips = profit_price_diff / (point * factor);

                                                      if(profit_pips >= trailing_start_pips)
                                                         {
                                                                  // compute new SL such that SL = current_price - trailing_step_pips (for buy)
                                                                        double new_sl_price;
                                                                              if(pos_type==POSITION_TYPE_BUY)
                                                                                       new_sl_price = current_price - PipsToPoints(trailing_step_pips);
                                                                                             else
                                                                                                      new_sl_price = current_price + PipsToPoints(trailing_step_pips);

                                                                                                            // only move SL forward (for buy, must be higher than existing SL)
                                                                                                                  bool need_modify = false;
                                                                                                                        if(pos_type==POSITION_TYPE_BUY && new_sl_price > pos_sl + SymbolInfoDouble(_Symbol,SYMBOL_POINT)/10.0) need_modify = true;
                                                                                                                              if(pos_type==POSITION_TYPE_SELL && new_sl_price < pos_sl - SymbolInfoDouble(_Symbol,SYMBOL_POINT)/10.0) need_modify = true;

                                                                                                                                    if(need_modify)
                                                                                                                                          {
                                                                                                                                                      MqlTradeRequest req; MqlTradeResult res;
                                                                                                                                                               ZeroMemory(req); ZeroMemory(res);
                                                                                                                                                                        req.action = TRADE_ACTION_SLTP;
                                                                                                                                                                                 req.position = ticket;
                                                                                                                                                                                          req.sl = NormalizeDouble(new_sl_price, (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
                                                                                                                                                                                                   req.symbol = _Symbol;
                                                                                                                                                                                                            req.magic = 123456;
                                                                                                                                                                                                                     bool ok = OrderSend(req, res);
                                                                                                                                                                                                                              if(!ok)
                                                                                                                                                                                                                                          PrintFormat("Trailing: modify failed retcode=%d comment=%s", res.retcode, res.comment);
                                                                                                                                                                                                                                                   else
                                                                                                                                                                                                                                                               PrintFormat("Trailing modified pos=%I64u newSL=%.5f", ticket, req.sl);
                                                                                                                                          }
                                                         }
}

//+------------------------------------------------------------------+
void OnTick()
{
      UpdateDailyCounters();

         if(DailyLossExceeded())
            {
                     Print("Daily loss limit exceeded — no more trades today.");
                           return;
            }

               if(tradesToday >= max_trades_per_day)
                  {
                           // limit trades per day reached
                                 return;
                  }

                     // trailing management for existing position
                        ManageTrailing();

                           // Determine signal
                              int signal = -1; // -1 no signal, 1 buy, 0 sell
                                 if(analisis==1) signal=1;
                                    else if(analisis==0) signal=0;
                                       else
                                          {
                                                   double ema200 = GetEMAValue(1);
                                                         if(ema200==EMPTY_VALUE) { Print("EMA read failed"); return; }
                                                               double close[];
                                                                     CopyClose(_Symbol, PERIOD_CURRENT, 0, 2, close);
                                                                           double priceClose = close[1];
                                                                                 bool upTrend = priceClose > ema200;
                                                                                       bool downTrend = priceClose < ema200;

                                                                                             double k=EMPTY_VALUE, d=EMPTY_VALUE;
                                                                                                   if(!GetStochastic(k,d,1)) { Print("Stochastic read failed"); return; }
                                                                                                         double rsi = GetRSI(1);
                                                                                                               if(rsi==EMPTY_VALUE) { Print("RSI read failed"); return; }

                                                                                                                     // rules: buy if upTrend and stochastic oversold cross up and rsi > threshold
                                                                                                                           if(upTrend && k < 30.0 && k > d && rsi > rsi_entry_buy_min) signal = 1;
                                                                                                                                 if(downTrend && k > 70.0 && k < d && rsi < rsi_entry_sell_max) signal = 0;
                                          }

                                             if(signal==-1) return;

                                                // check no positions open (only one pos allowed)
                                                   if(HasOpenPosition()) return;

                                                      double entry_price = (signal==1) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
                                                         double sl_price = 0.0, tp_price = 0.0;
                                                            if(signal==1)
                                                               {
                                                                        sl_price = entry_price - PipsToPoints(sl_pips);
                                                                              tp_price = entry_price + PipsToPoints(tp_pips);
                                                               } else {
                                                                        sl_price = entry_price + PipsToPoints(sl_pips);
                                                                              tp_price = entry_price - PipsToPoints(tp_pips);
                                                               }

                                                                  double lot = fixed_lot;
                                                                     if(use_risk) lot = CalculateLot(risk_percent, sl_pips);

                                                                        // prepare request
                                                                           MqlTradeRequest request; MqlTradeResult result;
                                                                              ZeroMemory(request); ZeroMemory(result);

                                                                                 request.action = TRADE_ACTION_DEAL;
                                                                                    request.symbol = _Symbol;
                                                                                       request.volume = lot;
                                                                                          request.deviation = slippage;
                                                                                             request.magic = 123456;
                                                                                                request.comment = "EA MinLoss";

                                                                                                   if(signal==1)
                                                                                                      {
                                                                                                               request.type = ORDER_TYPE_BUY;
                                                                                                                     request.price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
                                                                                                                           request.sl = NormalizeDouble(sl_price, (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
                                                                                                                                 request.tp = NormalizeDouble(tp_price, (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
                                                                                                      } else {
                                                                                                               request.type = ORDER_TYPE_SELL;
                                                                                                                     request.price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
                                                                                                                           request.sl = NormalizeDouble(sl_price, (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
                                                                                                                                 request.tp = NormalizeDouble(tp_price, (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
                                                                                                      }

                                                                                                         if(!OrderSend(request, result))
                                                                                                            {
                                                                                                                     PrintFormat("OrderSend failed. GetLastError()=%d retcode=%d comment=%s", GetLastError(), result.retcode, result.comment);
                                                                                                            }
                                                                                                               else
                                                                                                                  {
                                                                                                                           // OrderSend succeeded (result.order holds order ticket)
                                                                                                                                 PrintFormat("Order placed ticket=%I64d type=%d lot=%.2f", result.order, request.type, lot);
                                                                                                                                       tradesToday++;
                                                                                                                  }
}

//+------------------------------------------------------------------+
// Note: This EA implements basic history-based daily loss calculation,
//       indicator handles, position entry with risk-sizing, and a simple
//       trailing-stop modifier. For production, add robust error handling,
//       position management (multiple positions), better history parsing,
//       and full OnTradeTransaction logic for immediate trade updates.
//+------------------------------------------------------------------+

                                                                                                                  }
                                                                                                            }
                                                                                                      }
                                                                                                      }
                                                               }
                                                               }
                                          }
                  }
            }
}
                                                                                                                                          }
                                                         }
}
}
}
                  }
}
}
}
}
}
                                                                                                                                       }
                                                                                          }
                                                   }
                        }
                                                                                                                                                                                                }
                                                                                                                                          }
                                                                                 }
                        }
}
                                    }
                           }
}
}