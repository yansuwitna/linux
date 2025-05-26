
//+------------------------------------------------------------------+
//| Expert Advisor: EA_BB_RSI_BuySell_Advanced_Final                |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

// === INPUT ===
input double LotSize        = 0.01;
input int    SLPoints       = 100;
input int    TPPoints       = 150;
input int    BBPeriod       = 20;
input double BBDeviation    = 2.0;
input int    RSIPeriod      = 14;
input double RSI_Buy_Max    = 40.0;
input double RSI_Sell_Min   = 60.0;
input int    TradingStartHour = 8;
input int    TradingEndHour   = 17;
input int    TrailingStart    = 50;
input int    TrailingStep     = 20;

// === HANDLES & BUFFERS ===
int bb_handle, rsi_handle;
double upper[], lower[], rsiBuffer[];

//+------------------------------------------------------------------+
//| Fungsi bantu: TimeHour                                           |
//+------------------------------------------------------------------+
int TimeHour(datetime t) {
   MqlDateTime tm;
   TimeToStruct(t, tm);
   return tm.hour;
}

//+------------------------------------------------------------------+
int OnInit()
{
    bb_handle = iBands(_Symbol, PERIOD_M30, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
    rsi_handle = iRSI(_Symbol, PERIOD_M30, RSIPeriod, PRICE_CLOSE);

    if (bb_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE)
    {
        Comment("❌ Gagal inisialisasi indikator.");
        return INIT_FAILED;
    }

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
    int hourNow = TimeHour(TimeCurrent());
    if (hourNow < TradingStartHour || hourNow > TradingEndHour)
    {
        Comment("⏰ Di luar jam trading: ", hourNow, ":00");
        return;
    }

    if (CopyBuffer(bb_handle, 0, 0, 1, upper) <= 0 ||
        CopyBuffer(bb_handle, 2, 0, 1, lower) <= 0 ||
        CopyBuffer(rsi_handle, 0, 0, 1, rsiBuffer) <= 0)
    {
        Comment("❌ Gagal membaca data indikator.");
        return;
    }

    double close   = iClose(_Symbol, PERIOD_M30, 0);
    double upperBB = upper[0];
    double lowerBB = lower[0];
    double rsi     = rsiBuffer[0];
    double ma200   = iMA(_Symbol, PERIOD_M30, 200, 0, MODE_EMA, PRICE_CLOSE);

    string info =
        "🔰 EA BB-RSI Advanced" +
        "Balance     : $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n" +
        "Equity      : $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n" +
        "Margin      : $" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN), 2) + "\n" +
        "Free Margin : $" + DoubleToString(AccountInfoDouble(ACCOUNT_FREEMARGIN), 2) + "\n" +
        "Profit      : $" + DoubleToString(AccountInfoDouble(ACCOUNT_PROFIT), 2) + "\n" +
        "RSI         : " + DoubleToString(rsi, 2) + "\n" +
        "Upper BB    : " + DoubleToString(upperBB, 2) + "\n" +
        "Lower BB    : " + DoubleToString(lowerBB, 2) + "\n" +
        "MA200       : " + DoubleToString(ma200, 2) + "\n" +
        "Price       : " + DoubleToString(close, 2) + "\n";

    if (PositionsTotal() > 0)
    {
        TrailPositions();
        Comment(info + "⏳ Menunggu posisi selesai...");
        return;
    }

    double sl, tp;

    if (close <= lowerBB && rsi < RSI_Buy_Max && close > ma200)
    {
        sl = close - SLPoints * _Point;
        tp = close + TPPoints * _Point;
        if (trade.Buy(LotSize, _Symbol, close, sl, tp, "BUY BB-RSI"))
            info += "✅ BUY dibuka @ " + DoubleToString(close, 2);
        else
            info += "❌ Gagal membuka BUY";
    }
    else if (close >= upperBB && rsi > RSI_Sell_Min && close < ma200)
    {
        sl = close + SLPoints * _Point;
        tp = close - TPPoints * _Point;
        if (trade.Sell(LotSize, _Symbol, close, sl, tp, "SELL BB-RSI"))
            info += "✅ SELL dibuka @ " + DoubleToString(close, 2);
        else
            info += "❌ Gagal membuka SELL";
    }
    else
    {
        info += "🔍 Tidak ada sinyal valid.";
    }

    Comment(info);
}

//+------------------------------------------------------------------+
void TrailPositions()
{
    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (!PositionGetTicket(i)) continue;
        if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        ulong ticket     = PositionGetInteger(POSITION_TICKET);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double sl        = PositionGetDouble(POSITION_SL);
        double tp        = PositionGetDouble(POSITION_TP);
        int type         = (int)PositionGetInteger(POSITION_TYPE);

        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

        if (type == POSITION_TYPE_BUY)
        {
            double profitPoints = (bid - openPrice) / _Point;
            if (profitPoints > TrailingStart)
            {
                double newSL = bid - TrailingStep * _Point;
                if (newSL > sl)
                    trade.PositionModify(ticket, newSL, tp);
            }
        }
        else if (type == POSITION_TYPE_SELL)
        {
            double profitPoints = (openPrice - ask) / _Point;
            if (profitPoints > TrailingStart)
            {
                double newSL = ask + TrailingStep * _Point;
                if (newSL < sl)
                    trade.PositionModify(ticket, newSL, tp);
            }
        }
    }
}
