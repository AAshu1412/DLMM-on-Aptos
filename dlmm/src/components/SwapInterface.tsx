import { useState } from "react";
import { ArrowUpDown, RotateCcw, Settings } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import TokenSelector from "./TokenSelector";
import TransactionDetails from "./TransactionDetails";

const TOKENS = [
  { symbol: "ETH", name: "Ethereum", icon: "Ξ", balance: "3,42,343.564" },
  { symbol: "TRUMP", name: "TRUMP Token", icon: "🇺🇸", balance: "224.32" },
  { symbol: "BTC", name: "Bitcoin", icon: "₿", balance: "12.5" },
  { symbol: "SOL", name: "Solana", icon: "◎", balance: "1,250.0" },
];

const SwapInterface = () => {
  const [sellToken, setSellToken] = useState(TOKENS[0]);
  const [buyToken, setBuyToken] = useState(TOKENS[1]);
  const [sellAmount, setSellAmount] = useState("10");
  const [buyAmount, setBuyAmount] = useState("3424");
  const [sellValue, setSellValue] = useState("26,869.55");
  const [buyValue, setBuyValue] = useState("26,869.55");

  const handleTokenSwap = () => {
    const tempToken = sellToken;
    const tempAmount = sellAmount;
    const tempValue = sellValue;
    
    setSellToken(buyToken);
    setBuyToken(tempToken);
    setSellAmount(buyAmount);
    setBuyAmount(tempAmount);
    setSellValue(buyValue);
    setBuyValue(tempValue);
  };

  return (
    <div className="min-h-screen bg-background p-4 flex items-center justify-center">
      <div className="w-full max-w-md space-y-4">
        <Tabs defaultValue="swap" className="w-full">
          <TabsList className="grid w-full grid-cols-3 bg-secondary">
            <TabsTrigger value="swap" className="data-[state=active]:bg-surface">Swap</TabsTrigger>
            <TabsTrigger value="send" className="data-[state=active]:bg-surface">Send</TabsTrigger>
            <TabsTrigger value="buy" className="data-[state=active]:bg-surface">Buy</TabsTrigger>
          </TabsList>
          
          <TabsContent value="swap" className="space-y-4">
            <Card className="p-6 bg-card border border-card-border">
              {/* Sell Section */}
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium text-muted-foreground">SELL</span>
                  <Button variant="ghost" size="sm" className="h-6 p-1">
                    <Settings className="w-4 h-4 text-muted-foreground" />
                  </Button>
                </div>
                
                <div className="flex items-center justify-between">
                  <TokenSelector
                    selectedToken={sellToken}
                    onTokenSelect={setSellToken}
                    tokens={TOKENS}
                  />
                  <div className="text-right">
                    <Input
                      value={sellAmount}
                      onChange={(e) => setSellAmount(e.target.value)}
                      className="text-right text-2xl font-bold border-none bg-transparent p-0 h-auto focus:ring-0 focus:border-none"
                      placeholder="0"
                    />
                  </div>
                </div>
                
                <div className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-1 text-muted-foreground">
                    <span>💰</span>
                    <span>{sellToken.balance} {sellToken.symbol}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Button variant="ghost" size="sm" className="h-6 px-2 py-1 text-xs bg-secondary text-foreground">
                      MAX
                    </Button>
                    <span className="text-muted-foreground">~ ${sellValue}</span>
                    <Button variant="ghost" size="sm" className="h-6 w-6 p-0">
                      <RotateCcw className="w-3 h-3" />
                    </Button>
                  </div>
                </div>
              </div>

              {/* Swap Button */}
              <div className="flex justify-center my-4">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={handleTokenSwap}
                  className="h-8 w-8 p-0 rounded-full bg-secondary hover:bg-secondary-hover border border-border"
                >
                  <ArrowUpDown className="w-4 h-4" />
                </Button>
              </div>

              {/* Buy Section */}
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium text-muted-foreground">BUY</span>
                </div>
                
                <div className="flex items-center justify-between">
                  <TokenSelector
                    selectedToken={buyToken}
                    onTokenSelect={setBuyToken}
                    tokens={TOKENS}
                  />
                  <div className="text-right">
                    <Input
                      value={buyAmount}
                      onChange={(e) => setBuyAmount(e.target.value)}
                      className="text-right text-2xl font-bold border-none bg-transparent p-0 h-auto focus:ring-0 focus:border-none"
                      placeholder="0"
                    />
                  </div>
                </div>
                
                <div className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-1 text-muted-foreground">
                    <span>💰</span>
                    <span>{buyToken.balance} {buyToken.symbol}</span>
                  </div>
                  <span className="text-muted-foreground">~ ${buyValue}</span>
                </div>
              </div>

              {/* Transaction Details */}
              <TransactionDetails />

              {/* Swap Button */}
              <Button className="w-full bg-primary hover:bg-primary-hover text-primary-foreground font-medium py-3 mt-6">
                Swap
              </Button>
            </Card>
          </TabsContent>
          
          <TabsContent value="send">
            <Card className="p-6 bg-card border border-card-border">
              <p className="text-center text-muted-foreground">Send functionality coming soon...</p>
            </Card>
          </TabsContent>
          
          <TabsContent value="buy">
            <Card className="p-6 bg-card border border-card-border">
              <p className="text-center text-muted-foreground">Buy functionality coming soon...</p>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
};

export default SwapInterface;